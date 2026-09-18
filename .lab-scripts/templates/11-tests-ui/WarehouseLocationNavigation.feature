Feature: WarehouseLocationNavigation

Scenario: User can open the Warehouse Locations view from the sitemap
    Given I am logged in as '__TEST_USER__'
    And I open the '__PREFIX___warehouseapp' app
    When I click on 'Warehouse Locations' in the sitemap
    Then I should see the 'Active Warehouse Locations' view
