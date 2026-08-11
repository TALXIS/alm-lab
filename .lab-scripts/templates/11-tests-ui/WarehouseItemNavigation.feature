Feature: WarehouseItemNavigation

Scenario: User can open a warehouse item from the main view
    Given I am logged in as '__TEST_USER__'
    And I open the '__PREFIX___warehouseapp' app
    When I click on 'Warehouse Items' in the sitemap
    Then I should see the 'Active Warehouse Items' view