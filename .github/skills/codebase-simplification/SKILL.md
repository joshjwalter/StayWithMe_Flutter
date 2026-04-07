---
name: codebase-simplification
description: 'Comprehensive codebase analysis and optimization for simplicity. Use when: refactoring code to reduce complexity, eliminating code duplication, removing unused features, improving code readability, and reducing maintenance burden. Maintains full functionality while prioritizing simplicity over performance.'
argument-hint: 'Codebase or specific modules to analyze and simplify'
---

# Codebase Simplification and Optimization

## Overview

This skill provides a structured methodology to analyze your entire codebase, identify opportunities for simplification, and incrementally refactor code to reduce complexity while maintaining full functionality. The approach prioritizes **simplicity, readability, and maintainability** over performance metrics.

## When to Use

- Reducing code complexity and technical debt
- Eliminating duplicated code and redundant patterns
- Removing unused features, functions, or dependencies
- Improving readability and code clarity
- Making the codebase easier to maintain and extend
- Refactoring before adding new features
- Code reviews focused on simplification

## When NOT to Use

- Performance optimization or speed-critical paths
- Micro-optimizations for execution performance
- Resource usage optimization (memory, CPU)
- When code changes would reduce functionality

## Key Principles

| Principle | Definition |
|-----------|-----------|
| **Favor Clarity** | Code should be obvious to someone reading it for the first time |
| **DRY (Don't Repeat Yourself)** | Eliminate code duplication through abstraction and reuse |
| **Single Purpose** | Each function/class should have one clear responsibility |
| **Remove Waste** | Delete unused code, dead branches, and redundant logic |
| **Minimal Dependencies** | Reduce coupling between modules and external dependencies |
| **KISS (Keep It Simple, Stupid)** | Prefer simple solutions over complex ones |

## Step-by-Step Procedure

### Phase 1: Codebase Discovery & Analysis

**Goal**: Build a complete understanding of the codebase structure and identify simplification opportunities.

1. **Map the Architecture**
   - Identify all modules, packages, and their responsibilities
   - Document entry points (main.dart, app root, etc.)
   - List external dependencies and their purposes
   - Note cross-module dependencies and coupling points

2. **Dependency Analysis**
   - Identify unused imports across all files
   - Find unused packages in pubspec.yaml (or equivalent)
   - Detect circular dependencies between modules
   - Map which modules depend on which others

3. **Code Duplication Scan**
   - Search for similar/identical code patterns across files
   - Identify common logic that could be abstracted
   - Find repeated UI components or helper functions
   - Note similar business logic in different modules

4. **Complexity Hotspots**
   - Identify functions/methods that are too long (>50 lines)
   - Find deeply nested conditional logic (>3 levels)
   - Locate classes with too many responsibilities
   - Note functions with high cyclomatic complexity

5. **Dead Code Inventory**
   - List unused functions, methods, and classes
   - Find unreachable code branches
   - Identify unused constants or variables
   - Document commented-out code that could be removed

### Phase 2: Prioritization & Planning

**Goal**: Determine which simplifications will have the most impact without breaking functionality.

1. **Classify Opportunities**
   - **High Impact, Low Risk**: Remove dead code, consolidate duplicates
   - **Medium Impact, Low Risk**: Extract common logic, simplify conditionals
   - **Medium Impact, Medium Risk**: Refactor complex functions
   - **Low Impact**: Minor readability improvements

2. **Create Refactoring Plan**
   - Group related changes (e.g., all unused imports in one pass)
   - Order changes from low-risk to higher-risk
   - Identify which changes should be done together vs. separately
   - Flag changes that may need testing or verification

3. **Assess Testing Requirements**
   - Identify which simplifications need test coverage
   - Note any functionality that's brittle and needs validation
   - Plan smoke tests for critical paths

### Phase 3: Incremental Refactoring

**Goal**: Apply simplifications incrementally, maintaining functionality at each step.

1. **Dead Code Removal**
   - Remove unused imports (start here—zero risk)
   - Delete unused functions, classes, and methods
   - Remove commented-out code blocks
   - Clean up unused variables and constants

2. **Code Deduplication**
   - Extract common functions from duplicated code
   - Consolidate similar logic into shared utilities
   - Replace code-copied patterns with reusable components
   - Simplify repeated conditionals with helper functions

3. **Reduce Complexity**
   - Break large functions into smaller, focused ones
   - Flatten deeply nested conditionals using early returns
   - Simplify complex boolean logic
   - Extract magic numbers into named constants

4. **Improve Clarity**
   - Rename unclear variables and functions to be more descriptive
   - Add clarifying comments where intent is non-obvious
   - Simplify convoluted expressions
   - Improve consistency in naming conventions

5. **Module Decoupling** (if applicable)
   - Remove unnecessary cross-module dependencies
   - Replace tightly coupled code with dependency injection
   - Simplify module interfaces
   - Reduce public API surface

### Phase 4: Validation & Verification

**Goal**: Ensure all functionality works correctly after simplifications.

1. **Execute Existing Tests**
   - Run all unit tests to verify no breakage
   - Run integration tests if applicable
   - Check test coverage for refactored areas

2. **Manual Smoke Tests**
   - Test critical user workflows
   - Verify edge cases still work
   - Check any complex business logic paths

3. **Code Review**
   - Review changes for correctness
   - Verify simplifications maintain original intent
   - Ensure no latent bugs were introduced
   - Check for consistent style and patterns

4. **Documentation Updates**
   - Update architecture docs if module structure changed
   - Clarify any complex remaining logic with comments
   - Update README if setup/build process changed

## Example Workflow (Dart/Flutter Project)

```
1. Analysis Phase
   → Scan Flutter project structure and dependencies
   → Identify unused imports in lib/
   → Find duplicate widget or helper code
   → Locate functions >100 lines

2. Prioritization Phase
   → Plan removal of unused packages first
   → Schedule extraction of common widgets
   → Target top 3 complex functions for refactoring

3. Refactoring Phase
   → Remove unused imports (immediate)
   → Extract shared widget components
   → Break down complex functions
   → Rename unclear variables

4. Validation Phase
   → Run flutter test
   → Manual testing on hot reload
   → Review simplified functions
```

## Common Simplification Patterns

### Pattern: Unused Code Removal
```dart
// ❌ BEFORE: Dead code clutters understanding
void unusedFunction() { ... }
final _notUsedVariable = "...";
import 'package:unused_package/unused.dart';

// ✅ AFTER: Clean, focused codebase
// Removed unused definitions entirely
```

### Pattern: Extract Common Logic
```dart
// ❌ BEFORE: Duplicated logic in multiple places
void method1() { parsing(); validation(); processing(); }
void method2() { parsing(); validation(); processing(); }

// ✅ AFTER: Single responsibility, reusable
void _commonFlow() { parsing(); validation(); processing(); }
void method1() { _commonFlow(); }
void method2() { _commonFlow(); }
```

### Pattern: Flatten Nested Conditionals
```dart
// ❌ BEFORE: Hard to follow control flow
if (condition1) {
  if (condition2) {
    if (condition3) {
      doWork();
    }
  }
}

// ✅ AFTER: Clear, linear flow
if (!condition1 || !condition2 || !condition3) return;
doWork();
```

## Tools & Techniques

- **Static Analysis**: Use linters (dartanalyzer, ESLint) to detect dead code
- **Search & Replace**: Systematically find duplication patterns
- **Refactoring Tools**: Use IDE features (extract method, rename, etc.)
- **Version Control**: Commit incrementally to track changes and enable rollback
- **Tests**: Leverage existing test suite as a safety net during refactoring

## Success Metrics

- Reduced number of lines of code (LOC) without loss of functionality
- Fewer duplication instances detected by static analysis
- Improved cyclomatic complexity scores
- Increased code readability (measured by peer review feedback)
- All tests passing after refactoring
- Reduced maintenance burden and onboarding time

## Anti-Patterns to Avoid

| Don't | Why | Do Instead |
|------|-----|-----------|
| Optimize for performance while simplifying | Conflates two different goals | Focus solely on simplicity and functionality |
| Refactor without tests | Increases risk of bugs | Run tests frequently during refactoring |
| Change everything at once | Hard to identify what broke | Refactor incrementally, testing after each change |
| Over-abstract common code | Creates unnecessary indirection | Abstract only when duplication is clear |
| Remove comments from complex logic | Loses context and intent | Keep clarifying comments, improve clarity instead |

## Next Steps After Simplification

1. **Maintain Simplicity**: Use code review checklists to prevent re-accumulation of complexity
2. **Document Decisions**: Record why code is structured the way it is
3. **Monitor Metrics**: Track complexity/LOC over time to detect regression
4. **Iterate**: Make simplification a continuous practice, not a one-time event
