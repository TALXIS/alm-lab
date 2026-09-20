@live @mda
Feature: Warehouse Transaction Navigation

Scenario: User can open the Warehouse Transactions view from the sitemap
    Given I am logged in as 'a warehouse manager'
    And I open the 'almlab_warehouseapp' app
    When I click on 'Warehouse Transactions' in the sitemap
    Then I should see the 'Active Warehouse Transactions' view
