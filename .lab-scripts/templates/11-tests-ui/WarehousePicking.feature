Feature: Warehouse Picking
    As a warehouse floor worker
    I want to pick and restock items from the code app
    So that available quantities stay accurate and over-picking is blocked

    Background:
        Given I am logged in as '__TEST_USER__'
        And I open the warehouse picking app

    Scenario: Not enough stock blocks the pick
        Given I open the 'Wireless Mouse' item
        When I pick a quantity of '10'
        Then I should see the error 'Not enough product in stock. Available: 5, requested: 10.'

    Scenario: A valid pick updates the available quantity
        Given I open the 'Office Laptop' item
        When I pick a quantity of '5'
        Then the quantity on hand should read '95'
