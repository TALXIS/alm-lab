# Job J7 — Find an item quickly on a shared device (warehouse floor worker)
Feature: Finding an item on the floor
    As a warehouse floor worker
    I want to get to an item in as few taps as possible
    So that recording a movement does not interrupt the work

    Scenario: The item list is the first thing the app shows
        Given I am a warehouse floor worker
        When I open the picking app
        Then I see the items we stock

    Scenario: Opening an item from the list
        Given I am a warehouse floor worker
        And I am looking at the list of items
        When I open one of them
        Then I see that item's details
