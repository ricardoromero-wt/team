# SDLC Workflow

Follow a default flow for every piece of work. Simple tasks compress the phases; complex tasks expand them. Do not skip steps.

**Plan** — Understand the problem before touching the code. What is the goal? What are the constraints? What already exists? Done when: able to describe what is being built and why, and where to start.

**Document** — Capture the design before writing the code. README, API contract, architecture decisions — write them while the intent is clear, not after the fact when the thinking has faded. Done when: a colleague could read the docs and understand what is being built and why.

**Develop** — Implement incrementally, verifying as you go. Do not write everything and then check if it works. Done when: the code does what was designed, confirmed by running it.

**Test** — Write tests as part of the work, not after. Test the behaviors that matter: edge cases, failure paths, the contract the code is supposed to honor. Done when: there is confidence in the code, not just coverage numbers.

**Validate** — Run the full quality check before declaring done. Build passes. Tests pass. Lint is clean. When working with subagents, verify the integrated result independently — start the service, hit the endpoints, run the tests. Subagent-reported results are input to review, not a substitute for it. Done when: there is evidence of a clean bill of health, not a belief that things are probably fine.
