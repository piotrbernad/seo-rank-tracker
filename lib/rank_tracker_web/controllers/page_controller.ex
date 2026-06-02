defmodule RankTrackerWeb.PageController do
  use RankTrackerWeb, :controller

  def sitemap(conn, _params) do
    host = RankTrackerWeb.Endpoint.url()

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>#{host}/</loc>
        <changefreq>weekly</changefreq>
        <priority>1.0</priority>
      </url>
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  def home(conn, _params) do
    host = RankTrackerWeb.Endpoint.url()

    json_ld =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@graph" => [
          %{
            "@type" => "WebApplication",
            "name" => "SEO Rank Tracker",
            "url" => host,
            "description" =>
              "MCP server for AI agents to check Google search rankings. Track keyword positions across 35+ countries with a simple pay-per-use API.",
            "applicationCategory" => "SEO Tool",
            "operatingSystem" => "Any",
            "offers" => %{
              "@type" => "Offer",
              "price" => "0.0024",
              "priceCurrency" => "USD",
              "description" => "Pay-per-use rank check, no subscription required"
            },
            "featureList" => [
              "MCP protocol integration for AI agents",
              "Real-time Google SERP position checking",
              "Multi-keyword batch rank checking",
              "35+ country support",
              "Historical rank tracking",
              "Pay-per-use pricing at $0.0024/check",
              "Compatible with Claude Desktop, Cursor, VS Code, Windsurf"
            ]
          },
          %{
            "@type" => "FAQPage",
            "mainEntity" => [
              %{
                "@type" => "Question",
                "name" => "What is an SEO MCP server?",
                "acceptedAnswer" => %{
                  "@type" => "Answer",
                  "text" =>
                    "An SEO MCP (Model Context Protocol) server lets AI agents like Claude, Cursor, and VS Code Copilot check Google search rankings programmatically. Instead of manually checking positions, your AI agent calls tools like check_ranks to get real-time SERP data."
                }
              },
              %{
                "@type" => "Question",
                "name" => "How much does SEO Rank Tracker cost?",
                "acceptedAnswer" => %{
                  "@type" => "Answer",
                  "text" =>
                    "SEO Rank Tracker uses pay-per-use pricing at $0.0024 per rank check. There is no subscription, no monthly fee, and no minimum spend. $10 gets you approximately 4,100 rank checks."
                }
              },
              %{
                "@type" => "Question",
                "name" => "Which countries does SEO Rank Tracker support?",
                "acceptedAnswer" => %{
                  "@type" => "Answer",
                  "text" =>
                    "SEO Rank Tracker supports 35+ countries including the United States, United Kingdom, Germany, France, Japan, Brazil, and more across Europe, the Americas, Asia-Pacific, and the Middle East."
                }
              }
            ]
          }
        ]
      })

    conn
    |> assign(:page_title, "SEO Rank Tracker — SEO MCP Server for AI Agents | Google Position Tracking API")
    |> assign(:meta_description, "The simplest SEO MCP server for AI agents. Check Google search positions, track keyword rankings across 35+ countries. Real-time SERP API for Claude, Cursor, VS Code. Pay-per-use at $0.0024/check, no subscription.")
    |> assign(:canonical_url, host <> "/")
    |> assign(:og_title, "SEO Rank Tracker — The Simplest SEO MCP for AI Agents")
    |> assign(:og_description, "MCP server for AI agents to check Google rankings. Add domains, track keywords, monitor positions across 35+ countries. $0.0024/check, no subscription.")
    |> assign(:json_ld, json_ld)
    |> render(:home)
  end
end
