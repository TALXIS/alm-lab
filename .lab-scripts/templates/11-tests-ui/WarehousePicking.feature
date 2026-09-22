Feature: Warehouse Picking
    As a warehouse floor worker
    I want to pick and restock items from the code app
    So that available quantities stay accurate and over-picking is blocked

    # Assertions below read the starting quantity from the UI rather than assuming a fixed
    # seeded value — this data lives in a real, shared Dataverse environment (no test
    # fixture/teardown), and CP11's own "try it live" walkthrough asks the learner to pick
    # from these same records, so the absolute quantity drifts across lab runs.

    Background:
        Given I am logged in as '__TEST_USER__'
        And I open the warehouse picking app

    Scenario: Not enough stock blocks the pick
        Given I open the 'Wireless Mouse' item
        When I try to pick more than the available quantity
        Then I should see an error that the requested quantity exceeds the available stock

    Scenario: A valid pick updates the available quantity
        Given I open the 'Office Laptop' item
        When I pick a quantity of '5'
        Then the quantity on hand should have decreased by '5'

    # 3017620422003 is a real, stable Open Food Facts barcode (Nutella) - chosen because it's
    # unlikely to ever be removed from the public database, the same reasoning CP11's own
    # checkpoint script comments use it for.
    Scenario: Scanning a barcode links product data to an item
        Given I open the 'Wireless Mouse' item
        When I enter the barcode '3017620422003' and look it up
        Then I should see the product 'Nutella' in the scan preview
        When I link the scanned product to the item
        Then the item should show 'Nutella' as its linked product
