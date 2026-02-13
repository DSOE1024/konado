# Actor Positioning and Scaling

## Introduction

The Konado dialogue system uses a **screen block division algorithm** to achieve precise, adaptive positioning of character positions, while built-in tween animation transition logic balances positioning flexibility, adaptability, and visual experience.

The dialogue manager automatically generates instances based on dialogue content and manages them automatically.

## Actor Positioning

Unlike traditional dialogue system character positioning methods (such as fixed positions, fixed offsets, etc.), `Konado` uses **block division** to achieve precise, adaptive positioning of character positions, saving time on manual character position adjustments and ensuring that character positions are always within reasonable ranges in dialogue scenes, speeding up development efficiency.

At the same time, this positioning also allows designers to use tools like guidelines in other design tools for character positioning without manually adjusting character positions in the game engine.

### Horizontal Positioning (Left/Right Position)
The screen is divided into several equal parts (minimum 2 parts, maximum 15 parts, default 6 parts). Counting from left to right, characters can be placed between the 1st part and the penultimate part (for example, when divided into 6 parts, characters can be placed at the 1st to 5th division line positions), not sticking to the far left/right.

### Vertical Positioning (Top/Bottom Position)
The screen is divided into several equal parts (minimum 3 parts, maximum 15 parts, default 6 parts). Counting from top to bottom, characters can be placed between the 1st part and the penultimate part (for example, when divided into 3 parts, characters can be placed at the 1st to 2nd division line positions), not sticking to the top/bottom.

### Principle

The component divides the canvas container of the `Control` node carrying the character into `division` equal horizontal blocks (block count can be set ≥2), with block indices **increasing from left to right** (0 is the leftmost, division is the rightmost),

The valid range of `character_position` (character position index) is limited to `[1, division-1]` to avoid visual overflow issues caused by characters being completely left/right-aligned. The **center** of the character will be aligned with the block division line for display.

## Actor Scaling

After adjusting the texture scale by calling `set_texture_scale`, the position will be updated synchronously to ensure that the scaled character still aligns with the target block, avoiding visual overflow issues caused by scaling.

## Adaptive Updates

When the canvas container size changes, character position index is modified, or texture is scaled/replaced, the component will automatically trigger the `_on_resized()` method to recalculate and update the character position; if tween animation is enabled, position updates will transition with smooth animation, otherwise they will take effect immediately.