# Job J4 — Check one item's stock position against its reorder point on demand
#          (warehouse manager)
Feature: Checking one item's stock position
    As a warehouse manager
    I want to ask an item how it is doing against its own reorder point
    So that I can answer a question about one item without reading a list

    Scenario: An item below its reorder point reports that it needs restocking
        Given I am a warehouse manager
        And I have opened an item whose stock is below its reorder point
        When I check its stock level
        Then I am told how many are on hand
        And I am told it is below its reorder point

    Scenario: A healthy item reports that it is fine
        Given I am a warehouse manager
        And I have opened an item whose stock is above its reorder point
        When I check its stock level
        Then I am told it is above its reorder point
