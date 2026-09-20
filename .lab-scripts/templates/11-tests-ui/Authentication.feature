@auth @live @mda
Feature: Authentication
    As someone about to run the browser scenarios
    I want one command that establishes a signed-in session
    So that every scenario after it runs headless without touching a login page

    # This is the analogue of `npm run auth:mda:headful` in Microsoft's Playwright samples,
    # except there is nothing to remember: the same Given below is the first line of every
    # browser scenario, so an expired session re-authenticates wherever it is noticed. Run this
    # one on its own when you want that to happen deliberately - before a demo, or the first
    # time on a tenant whose sign-in needs MFA approved by hand:
    #
    #     TXC_HEADLESS=false dotnet test src/Tests.UI --filter "TestCategory=auth"

    Scenario: A warehouse manager has a usable session
        Given I am logged in as 'a warehouse manager'
        And I open the '__PREFIX___warehouseapp' app
        When I click on 'Warehouse Items' in the sitemap
        Then I should see the 'Active Warehouse Items' view
