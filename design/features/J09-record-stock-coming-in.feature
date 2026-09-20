# Job J9 — Record stock coming in (warehouse floor worker)
Feature: Recording stock coming in
    As a warehouse floor worker
    I want a delivery recorded against the item it belongs to
    So that the quantity on hand rises when goods actually arrive

    Scenario: A movement in raises what is on hand
        Given I am a warehouse floor worker
        And I have opened an item
        When I record twenty of it coming in
        Then twenty more are on hand

    Scenario: Stock coming in is never refused for being too large
        Given I am a warehouse floor worker
        And I have opened an item
        When I record a thousand of it coming in
        Then a thousand more are on hand
