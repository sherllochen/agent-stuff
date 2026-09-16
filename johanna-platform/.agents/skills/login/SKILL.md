---
name: login
description: Logs in to the application with a given customer ID.
---

# Login Skill

This skill provides a workflow for logging into the application using a customer ID.

## Workflow 1: Manual Entry

This workflow is useful when you want to log in with a customer ID that is not in the list of test customers.

1.  **Navigate to the login page**: If you are not already on the login page, navigate to `http://localhost:3000/banking/sign_in`.
2.  **Take a snapshot**: Use `mcp_chrome_devtools_take_snapshot` to get the current state of the page and identify the UI elements.
3.  **Find the customer ID input field**: Look for an input element with the value `123456789`. This is the customer ID input field.
4.  **Fill the customer ID**: Use `mcp_chrome_devtools_fill` to enter the desired customer ID into the input field.
5.  **Find the login button**: Look for a button with the text "Login".
6.  **Click the login button**: Use `mcp_chrome_devtools_click` to click the login button.
7.  **Verify login**: After clicking the login button, take another snapshot to verify that the login was successful. You should see a different page, for example the accounts page.

## Workflow 2: Clicking from the list

This is the preferred workflow when logging in with a test customer that is already listed on the page.

1.  **Navigate to the login page**: If you are not already on the login page, navigate to `http://localhost:3000/banking/sign_in`.
2.  **Take a snapshot**: Use `mcp_chrome_devtools_take_snapshot` to get the current state of the page and identify the UI elements.
3.  **Find the customer ID link**: In the list of customers, find the link that corresponds to the customer ID you want to log in with. For example, to log in with customer "1000", find the link with that text.
4.  **Click the customer ID link**: Use `mcp_chrome_devtools_click` to click on the link.
5.  **Verify login**: After clicking the link, take another snapshot to verify that the login was successful. You should see a different page, for example the accounts page.
