# Job J2 — Maintain the list of sites, retiring one without losing its history
#          (warehouse manager)
Feature: Maintaining the list of sites
    As a warehouse manager
    I want to keep the list of sites current
    So that every item can be placed somewhere real

    Scenario: A new site is opened
        Given I am a warehouse manager
        When I add a site with a name, an address and a capacity
        Then the site can be chosen when placing an item

    Scenario: A site is retired without losing what was stored there
        Given I am a warehouse manager
        And a site holds items
        When I retire the site
        Then the site is no longer offered when placing an item
        And the items it held still show it as their site
