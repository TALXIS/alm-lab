Feature: WarehouseTransactionNavigation

Scenario: User can open the Warehouse Transactions view from the sitemap
    Given I am logged in as 'your-user@yourtenant.onmicrosoft.com'
    And I open the '_warehouseapp' app
    When I click on 'Warehouse Transactions' in the sitemap
    Then I should see the 'Active Warehouse Transactions' view

