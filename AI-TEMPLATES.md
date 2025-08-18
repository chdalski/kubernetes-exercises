# AI Templates

## Create a set of tasks

Create an exhaustive set of challenging, real-world Kubernetes CKAD exam tasks for the topic "Custom Resource Definitions" as raw-markdown file.

- Use different names per task
- Explicitly specify which image to use (if one is needed)
- Use the following template for each task.
- Each task should include:
- A unique task number and name.
- An "__Objective__:" section describing the goal.
- A "Requirements:" section as a bullet list.
- A "__Predefined Resources:__" section (if any).
  - For resources that needs to be created in advance define the manifest using start-tag "---yaml-start" and end-tag "---yaml-end
- A collapsible help section using <details><summary>help</summary></details>.

## Create a verification function for a task

```markdown

I'll give you a set of CKAD tasks and I'd like you to create a set of verification scripts for the tasks.

This following definition outlines the mandatory rules and best practices for creating bash verification scripts for CKAD tasks. Please adhere to these specifications ensures consistency, robustness, and clear debugging output.

- Disable shellcheck SC2329 for the function (# shellcheck disable=SC2329)
- The function name should follow the pattern "verify_task<tasknumber>"
- At the beginning of the function create a non-local variable TASK_NUMBER="<tasknumber>".
- Next, create local variables with predefined values after the TASK_NUMBER.
- For each variable that is not predefined, use local on the line just before its first assignment, instead of declaring all local variables at the beginning of the function.
- Only assign a variable if its value is used in a check, comparison, or further processing. Do not assign variables for values that are not used, and do not assign variables solely for documentation or debug output. If a command is only used to check for success or failure, do not assign its output to a variable unless you need to process that output. If you run a command whose output is not assigned to a variable, always redirect its output (stdout and stderr) to /dev/null to prevent any unintended printing.
- Add a brief comment before each major verification step explaining what is being checked.
- Every jq and kubectl command must be followed by error handling and a debug message if it fails.
- Use a consistent naming scheme for variables extracted from JSON (e.g., prefix with rs_ for ReplicaSet-related variables).
- When verifying multiple resources (e.g., pods), include debug output for each item checked, especially on failure.
- If the verification fails at any point, a pre-existing bash function called "failed" should be called and the function should return.
- If all checks are successful, a pre-existing function called "solved" should be called and the function should return.
- If all checks pass, print a debug message indicating successful verification before calling solved.
- Don't use "$?" to verify return values; instead, use "|| { failed; return; }".
- Don't use files to store values - always use local variables.
- Always quote variable expansions (e.g., "$var") to prevent word splitting and globbing.
- Make sure not to print any information to the user (stdout), except for debug messages as described below.
- Make sure not to print any errors to the user (use "2>/dev/null" where needed).
- Make sure to query the Kubernetes API for information (i.e., a secret resource) only once, get it as JSON, and use the JSON variable afterwards.
- Use JSON with jq for the verification (if needed).
- Use an indent size of 2 spaces.
- Verify everything that is specifically expected in the requirements section of the task.
- Define expected values as local variables at the beginning of the function under the TASK_NUMBER.
- For all meaningful verification steps and failure points, use the already provided debug function to print context-specific debug messages. Do not use echo or print statements directly for debug output.
- The debug function is already defined as follows and should not be redefined in your function:
bash...
debug() {
  [ "${CKAD_EXAM_DEBUG}" = "true" ] && echo "[DEBUG][Task ${TASK_NUMBER}] $1"
}
...
- Debug messages should clearly state what is being checked, and in case of failure, what was expected and what was found.
- If you need to use index variables (i. e. for "for" loops, etc.) use local variables where possible.

Can you do that?
```
