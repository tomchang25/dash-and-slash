# Placeholder SFX Prompt

Generate deterministic placeholder SFX YAML for the Godot template synth pipeline.

Inputs:

- Sound intent: `<short gameplay/UI intent>`
- Desired sound id: `<snake_case_id>`
- Mood: `<bright/dark/soft/noisy/mechanical/etc>`
- Frequency of playback: `<rare/normal/frequent>`

Output requirements:

- Return only YAML, no fences or commentary.
- Follow `dev/tools/prompts/yaml_generation/sfx.md`.
- Use a stable integer `seed`.
- Use `variant_count: 1` for rare sounds, 2-3 for frequent sounds.
- Keep total duration under 0.25 seconds unless the sound is intentionally a flourish.
