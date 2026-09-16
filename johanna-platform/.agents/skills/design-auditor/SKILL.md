---
name: design-auditor
description: Audits a web page against a design, checks for errors, and proposes code changes for web and mobile views.
---

# Design Auditor Skill

This skill provides a comprehensive workflow for auditing a web page against a design, considering responsive layouts and detailed CSS properties.

## High-Level Workflow

1.  **Clarify Scope**:
    *   Ask the user whether the design is for **mobile** or **web**.
    *   If mobile, ask if you should use a specific device simulation.

2.  **Prepare the Environment**:
    *   Navigate to the correct URL.
    *   Log in if necessary (using the `login` skill).
    *   If auditing a mobile design, set the device simulation on the login page *before* logging in.
    *   Resize the viewport to match the design if necessary.

3.  **Gather Inputs & Check for Errors**:
    *   Take a screenshot and structural snapshot of the page.
    *   Fetch console logs and report any errors.

4.  **Analyze and Compare**:
    *   **Visual Comparison (Multi-modal)**: Use a multi-modal prompt to get a high-level overview of visual discrepancies between the design image and the screenshot.
    *   **CSS Property Analysis**: For each discrepancy identified, programmatically get the computed CSS styles (`color`, `font-size`, `margin`, `padding`, etc.) of the relevant elements using `mcp_chrome_devtools_evaluate_script`.
    *   Compare the computed styles against the styles apparent in the design image.

5.  **Report Findings**:
    *   Provide a detailed report, combining the visual analysis with the specific CSS property mismatches.

6.  **Generate Code Changes**:
    *   Based on the detailed findings, identify source files and generate code patches to fix the issues.

## Detailed Steps

1.  **Clarify Scope**:
    *   Start by asking the user: "Is this design for a mobile or web view?"
    *   If "mobile", ask: "Should I use a specific device simulation (e.g., 'Default android')?"

2.  **Prepare Environment**:
    *   Navigate to the target URL. If redirection to a login page occurs, use the `login` skill.
    *   **CRITICAL**: If a mobile simulation is needed, it must be set on the login page *before* clicking the login button.
    *   After logging in and navigating to the correct page, you can use `mcp_chrome_devtools_emulate` to further refine the viewport if needed.

3.  **Gather Inputs & Check for Errors**:
    *   `mcp_chrome_devtools_take_screenshot`
    *   `mcp_chrome_devtools_take_snapshot`
    *   `mcp_chrome_devtools_list_console_messages --types error,warn`
    *   Report any console errors to the user immediately.

4.  **Analyze and Compare**:
    *   **Visual Comparison**: Perform the multi-modal comparison as before to get a list of visual differences.
    *   **CSS Analysis**: For each identified discrepancy:
        *   Get the `uid` of the element from the snapshot.
        *   Use `mcp_chrome_devtools_evaluate_script` to get its computed styles. Example:
            ```javascript
            // Script to get key styles for an element
            (element) => {
              const style = window.getComputedStyle(element);
              return JSON.stringify({
                color: style.color,
                backgroundColor: style.backgroundColor,
                fontSize: style.fontSize,
                fontFamily: style.fontFamily,
                fontWeight: style.fontWeight,
                margin: style.margin,
                padding: style.padding,
                border: style.border,
              });
            }
            ```

5.  **Report Findings**:
    *   Present a comprehensive report. For each issue, include:
        *   A description of the visual problem.
        *   The expected style from the design.
        *   The actual computed style from the live page.

6.  **Generate Code Changes**:
    *   Ask the user to proceed.
    *   Use the detailed report to find the source files and generate `replace` calls with specific instructions to correct the CSS.
