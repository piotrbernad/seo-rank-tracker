defmodule RankTracker.RankChecker do
  @moduledoc """
  Manages rank check jobs with global concurrency control.
  LiveViews subscribe to updates via PubSub, this module handles execution.
  """
  use GenServer
  require Logger

  alias RankTracker.Rankings
  alias RankTracker.Billing

  @max_concurrency 5
  @pubsub RankTracker.PubSub

  defstruct queue: :queue.new(),
            active: %{},
            active_count: 0

  # Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @doc """
  Enqueue a batch of combination_ids for a user.
  Returns {:ok, job_id} immediately. Subscribe to "rank_checks:USER_ID" for updates.
  """
  def enqueue(user_id, combination_ids) do
    job_id = Ecto.UUID.generate()

    case Billing.sufficient_funds?(user_id, length(combination_ids)) do
      true ->
        GenServer.cast(__MODULE__, {:enqueue, job_id, user_id, combination_ids})
        broadcast(user_id, {:job_started, job_id, length(combination_ids)})
        {:ok, job_id}

      false ->
        {:error, :insufficient_funds}
    end
  end

  @doc """
  Subscribe to rank check updates for a user.
  Messages: {:rank_checked, combo_id, result}, {:job_complete, job_id}
  """
  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, "rank_checks:#{user_id}")
  end

  # GenServer callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:enqueue, job_id, user_id, combination_ids}, state) do
    items =
      Enum.map(combination_ids, fn combo_id ->
        %{job_id: job_id, user_id: user_id, combo_id: combo_id}
      end)

    new_queue =
      Enum.reduce(items, state.queue, fn item, q ->
        :queue.in(item, q)
      end)

    state = %{state | queue: new_queue}
    {:noreply, dispatch(state)}
  end

  @impl true
  def handle_info({:task_done, item, result}, state) do
    broadcast(item.user_id, {:rank_checked, item.combo_id, result})

    active = Map.delete(state.active, item.combo_id)
    state = %{state | active: active, active_count: state.active_count - 1}

    remaining_for_job =
      :queue.to_list(state.queue)
      |> Enum.count(&(&1.job_id == item.job_id))

    active_for_job =
      state.active
      |> Enum.count(fn {_k, v} -> v.job_id == item.job_id end)

    if remaining_for_job == 0 and active_for_job == 0 do
      broadcast(item.user_id, {:job_complete, item.job_id})
    end

    {:noreply, dispatch(state)}
  end

  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # Private

  defp dispatch(%{active_count: count} = state) when count >= @max_concurrency do
    state
  end

  defp dispatch(state) do
    case :queue.out(state.queue) do
      {{:value, item}, rest} ->
        pid = self()

        Task.Supervisor.start_child(RankTracker.TaskSupervisor, fn ->
          result =
            try do
              Rankings.check_rank_with_billing(item.combo_id, item.user_id)
            rescue
              e ->
                Logger.error("Rank check crashed: #{Exception.message(e)}")
                {:error, :crashed}
            end

          send(pid, {:task_done, item, result})
        end)

        state = %{
          state
          | queue: rest,
            active: Map.put(state.active, item.combo_id, item),
            active_count: state.active_count + 1
        }

        dispatch(state)

      {:empty, _} ->
        state
    end
  end

  defp broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, "rank_checks:#{user_id}", message)
  end
end
