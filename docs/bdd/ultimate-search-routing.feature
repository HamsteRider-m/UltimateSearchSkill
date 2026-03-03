Feature: UltimateSearch routing reliability
  Ensure the skill chooses Grok/Tavily/agent-browser consistently for different query intents.

  Scenario: X/Twitter discussion should route to Grok first
    Given a query "检索一下X上有关伊朗战争讨论"
    When the agent selects search tools
    Then the first command must be "grok-search.sh --query \"...\" --platform \"X\""
    And the follow-up verification should include Tavily or another independent source

  Scenario: Full-text extraction after search
    Given a query requiring complete page content
    When the agent has identified target URLs
    Then it should run "web-fetch.sh --url \"...\""
    And output source links for key claims

  Scenario: Dynamic page requires browser collaboration
    Given target content hidden behind JS rendering, login, or button interactions
    When direct extraction is incomplete
    Then it must use "agent-browser open/snapshot/click/wait"
    And feed the final resolved URL back into "web-fetch.sh"

  Scenario: Fact answer must be cross-verified
    Given a factual query with potential staleness
    When the answer is prepared
    Then evidence must include at least 2 independent sources
    And confidence must be labeled High/Medium/Low
