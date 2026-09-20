# Job J10 — See how many of an item are on hand before promising any
#           (warehouse floor worker)
Feature: Seeing what is on hand
    As a warehouse floor worker
    I want the quantity I am shown to be the quantity that is there
    So that I do not promise goods we do not have

    Scenario: An item shows its current quantity
        Given I am a warehouse floor worker
        When I open an item
        Then I see how many are on hand

    Scenario: The quantity reflects a movement as soon as it is recorded
        Given I am a warehouse floor worker
        And I have opened an item
        When I record five of it going out
        Then the quantity I am shown has dropped by five
