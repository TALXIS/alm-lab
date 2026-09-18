Feature: WarehouseTransactionNavigation

Scenario: User can open the Warehouse Transactions view from the sitemap
    Given I am logged in as '__TEST_USER__'
    And I open the '__PREFIX___warehouseapp' app
    When I click on 'Warehouse Transactions' in the sitemap
    Then I should see the 'Active Warehouse Transactions' view
