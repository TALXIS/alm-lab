Feature: WarehouseCrossAreaNavigation
    As a warehouse manager
    I want to move between every area of the app in one session
    So that a change to one area's navigation can't silently break the others

Scenario: User can move between warehouse areas without losing app context
    Given I am logged in as 'your-user@yourtenant.onmicrosoft.com'
    And I open the '_warehouseapp' app
    When I click on 'Warehouse Items' in the sitemap
    Then I should see the 'Active Warehouse Items' view
    When I click on 'Warehouse Locations' in the sitemap
    Then I should see the 'Active Warehouse Locations' view
    When I click on 'Warehouse Transactions' in the sitemap
    Then I should see the 'Active Warehouse Transactions' view

