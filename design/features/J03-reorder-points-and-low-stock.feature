# Job J3 — Set the reorder point per item and see which items have reached it
#          (warehouse manager)
Feature: Knowing which items are running low
    As a warehouse manager
    I want items at or below their reorder point to stand out wherever they are listed
    So that restocking happens before we run out rather than after

    Scenario: An item at its reorder point is marked as low
        Given I am a warehouse manager
        And an item's stock has fallen to its reorder point
        When I look at the list of items
        Then that item is marked as low on stock

    Scenario: An item above its reorder point is not marked
        Given I am a warehouse manager
        And an item holds more than its reorder point
        When I look at the list of items
        Then that item is not marked as low on stock

    Scenario: An item with no reorder point still warns when stock is nearly gone
        Given I am a warehouse manager
        And an item has no reorder point set
        And it holds fewer than ten
        When I look at the list of items
        Then that item is marked as low on stock
