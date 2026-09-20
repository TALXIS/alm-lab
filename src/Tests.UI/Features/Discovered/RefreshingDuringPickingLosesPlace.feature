Feature: Refreshing the app while working on an item

  A picker who refreshes while looking at an item is returned to the
  full item list rather than the item they were working on.

  Scenario: Refreshing returns the picker to the item list
    Given the picker is viewing the details of a single item
    When the picker refreshes the app
    Then the full item list is shown
    And the item the picker was working on is no longer on screen
