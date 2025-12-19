# Logging Guide - Plan Creation

## Overview
Comprehensive logging has been added to the plan creation flow to help debug issues. The logs track the entire process from UI submission to database insertion.

## Log Flow

### 1. UI Layer (CreatePlanDialog)
**Tag:** `CreatePlanDialog`

**Logs:**
- `I: === Starting plan creation from UI ===` - User initiated plan creation
- `D: Plan name: {name}` - Plan name entered
- `D: Goal ID: {goalId}` - Associated goal
- `D: Repeat type: {type}` - Selected repeat type
- `D: Selected days of week: {days}` - For daysOfWeek type
- `D: Start date: {start}, End date: {end}` - Date range
- `D: TaskConfig created: ...` - Task configuration details
- `D: RepeatRule created: ...` - Repeat rule details
- `D: RepeatRule.isValid: {valid}` - Validation status
- `D: Calling planListProvider.createPlan...` - About to call service
- `I: ✓ Plan created successfully: {planId}` - Success
- `W: Plan creation returned null` - Service returned null (failure)
- `E: Failed to create plan from UI` - Exception occurred

### 2. Service Layer (PlanManagementService)
**Tag:** `PlanManagementService`

**Logs:**
- `I: createPlan called: userId={id}, goalId={id}, name={name}` - Service method entry
- `D: Plan details: startDate={date}, endDate={date}` - Date details
- `D: RepeatRule: type={type}, customDays={days}, selectedDaysOfWeek={list}` - Rule details
- `D: TaskConfig: durationMinutes={min}, repeatCount={count}, evaluationOptions={opts}` - Config details
- `D: Step 1: Validating goal exists...` - Checking goal
- `D: Goal found: {id}, title={title}` - Goal validated
- `E: Goal not found: {goalId}` - Goal missing
- `D: Step 2: Checking goal ownership...` - Permission check
- `D: Ownership verified` - Permission OK
- `E: Permission denied: goal.userId={id}, userId={id}` - Permission failed
- `D: Step 3: Validating plan creation...` - Plan validation
- `D: Plan validation passed` - Validation OK
- `E: Plan validation failed: {errors}` - Validation errors
- `D: Step 4: Creating plan in repository...` - About to save
- `I: Plan created successfully: {planId}` - Repository success
- `D: Step 5: Adding plan to goal...` - Linking to goal
- `D: Plan added to goal` - Link successful
- `D: Step 6: Generating initial task(s)...` - Task generation
- `I: Generated initial task for plan {planId}: {taskId}` - Task created
- `D: No task generated for plan {planId}` - No task created
- `D: Plan is not active, skipping task generation` - Plan inactive
- `I: ✓ Plan creation completed successfully: {planId}` - Complete success
- `E: Failed to create plan` - Exception with stack trace

### 3. Data Layer (PlanDAO)
**Tag:** `PlanDAO`

**Logs:**
- `D: insertPlan called: id={id}, name={name}` - DAO method entry
- `D: Plan data to insert: repeatType={type}, selectedDaysOfWeek={json}, taskConfig={json}` - Data to insert
- `I: Plan inserted successfully: {planId}` - Database insert OK
- `E: Failed to insert plan: {planId}` - Database error with stack trace

### 4. Task Generation (TaskGenerationService)
**Tag:** `TaskGenerationService`

**Existing logs include:**
- `D: generateNextTask called for plan: {name}` - Entry point
- `D: _generateDaysOfWeekTasks called for plan: {name}` - For daysOfWeek type
- `D: Plan is active ✓` - Plan status check
- `D: Getting last task for plan...` - Finding previous task
- `I: Creating task in database: {name}` - About to create task
- `I: Task created successfully ✓` - Task creation success
- `E: Failed to create task` - Task creation failed

## How to View Logs

### Android Studio / VS Code
1. Run the app in debug mode
2. Open the Debug Console / Logcat
3. Filter by tags: `CreatePlanDialog`, `PlanManagementService`, `PlanDAO`, `TaskGenerationService`

### Command Line (Android)
```bash
# View all logs
flutter run -v

# Filter specific tags
adb logcat | grep -E "CreatePlanDialog|PlanManagementService|PlanDAO"
```

## Common Error Patterns

### 1. Goal Not Found
```
[PlanManagementService] E: Goal not found: {goalId}
```
**Cause:** Invalid goalId passed from UI
**Solution:** Check goal selection logic

### 2. Validation Failed
```
[PlanManagementService] E: Plan validation failed: {errors}
```
**Cause:** Invalid plan data (e.g., empty selectedDaysOfWeek for daysOfWeek type)
**Solution:** Check validation in _validatePlanCreation and RepeatRule.isValid

### 3. Database Insert Failed
```
[PlanDAO] E: Failed to insert plan: {planId}
```
**Cause:** Database constraint violation or SQL error
**Solution:** Check planMap data and database schema

### 4. Invalid RepeatRule
```
[CreatePlanDialog] D: RepeatRule.isValid: false
```
**Cause:** selectedDaysOfWeek is null/empty for daysOfWeek type
**Solution:** UI validation should prevent this, but check day selector logic

## Debugging Steps

1. **Check UI logs first** - Verify data is collected correctly from form
2. **Check RepeatRule.isValid** - Ensure validation passes
3. **Follow service logs** - Track which step fails
4. **Check DAO logs** - Verify data format before database insert
5. **Review stack traces** - Error logs include full stack trace

## Example Success Flow

```
[CreatePlanDialog] I: === Starting plan creation from UI ===
[CreatePlanDialog] D: Plan name: 周一三五跑步
[CreatePlanDialog] D: Repeat type: RepeatType.daysOfWeek
[CreatePlanDialog] D: Selected days of week: [1, 3, 5]
[CreatePlanDialog] D: RepeatRule.isValid: true
[PlanManagementService] I: createPlan called: userId=user-123, goalId=goal-456, name=周一三五跑步
[PlanManagementService] D: RepeatRule: type=daysOfWeek, selectedDaysOfWeek=[1, 3, 5]
[PlanManagementService] D: Step 1: Validating goal exists...
[PlanManagementService] D: Goal found: goal-456, title=健康目标
[PlanManagementService] D: Step 2: Checking goal ownership...
[PlanManagementService] D: Ownership verified
[PlanManagementService] D: Step 3: Validating plan creation...
[PlanManagementService] D: Plan validation passed
[PlanManagementService] D: Step 4: Creating plan in repository...
[PlanDAO] D: insertPlan called: id=plan-789, name=周一三五跑步
[PlanDAO] D: Plan data to insert: repeatType=daysOfWeek, selectedDaysOfWeek=[1,3,5], ...
[PlanDAO] I: Plan inserted successfully: plan-789
[PlanManagementService] I: Plan created successfully: plan-789
[PlanManagementService] D: Step 5: Adding plan to goal...
[PlanManagementService] D: Plan added to goal
[PlanManagementService] D: Step 6: Generating initial task(s)...
[TaskGenerationService] D: generateNextTask called for plan: 周一三五跑步
[TaskGenerationService] D: _generateDaysOfWeekTasks called for plan: 周一三五跑步
[TaskGenerationService] I: Creating task in database: 周一三五跑步
[TaskGenerationService] I: Task created successfully ✓
[PlanManagementService] I: Generated initial task for plan plan-789: task-101
[PlanManagementService] I: ✓ Plan creation completed successfully: plan-789
[CreatePlanDialog] I: ✓ Plan created successfully: plan-789
```

## Notes

- `I` = Info (important milestones)
- `D` = Debug (detailed information)
- `W` = Warning (non-fatal issues)
- `E` = Error (failures with stack traces)

All error logs include stack traces for debugging.
