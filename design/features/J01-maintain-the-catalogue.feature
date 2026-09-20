# Job J1 — Maintain the catalogue of items (warehouse manager)
Feature: Maintaining the item catalogue
    As a warehouse manager
    I want to add and correct the goods we stock
    So that the catalogue reflects what the company actually holds

    Scenario: A new item joins the catalogue
        Given I am a warehouse manager
        When I add an item with a name, a stock-keeping code and the site it sits at
        Then the item appears in the catalogue at that site

    Scenario: An item cannot be added without a stock-keeping code
        Given I am a warehouse manager
        When I try to add an item with no stock-keeping code
        Then I am told the stock-keeping code is required
        And the item is not added

    Scenario: A correction to an item is kept
        Given I am a warehouse manager
        And an item is in the catalogue
        When I change its unit price
        Then the catalogue shows the new price
