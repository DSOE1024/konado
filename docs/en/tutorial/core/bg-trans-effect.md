# Background Transition Effects

## Preface

Background transition effects refer to the effect where the background image exits from the current scene while the background image of the new scene enters when switching scenes. This effect can increase visual impact and enhance user experience. Reading this chapter can help you implement custom background transition effects.

## Background Switching Shader Specification

To uniformly manage and play background transition effects, we have established a Shader specification as follows:

The shader type must be `canvas_item`

```glsl
shader_type canvas_item;
```

The following three parameters must be implemented:

```glsl
uniform float progress : hint_range(0, 1) = 0.0; // Transition progress 0=only current 1=only target
uniform sampler2D current_texture : hint_default_black; // Current texture
uniform sampler2D target_texture : hint_default_black; // Target texture
```

- progress: Transition progress, ranging from 0 to 1, where 0 means only the current texture is displayed, and 1 means only the target texture is displayed.
- current_texture: Current texture, the texture displayed when no scene is switched.
- target_texture: Target texture, the texture displayed after switching scenes.

## Background Switching Effect Configuration

At the same time, switching backgrounds is a dynamic process, so the following should also be supplemented:

Define the BackgroundTransitionEffectsType enumeration to identify the background switching effect type.
```
YOUR_EFFECT_SHADER
```

Define the shader variable, it is recommended to use the `preload` function to load the Shader file.
```
var your_effect_shader: Shader = preload("res://path/to/your_effect_shader.shader")
```

Next, you need to implement the background switching effect configuration of the YOUR_EFFECT_SHADER type.

```gdscript
BackgroundTransitionEffectsType.YOUR_EFFECT_SHADER: {
	"shader": your_effect_shader,  // Background switching Shader, should be consistent with the variable above
	"duration": 1.0,  // Transition duration, default is 1.0s
	"progress_target": 1.0,  // Target progress, default is 1.0
	"tween_trans": Tween.TRANS_LINEAR  // Easing type during switching
}
```

Next, test the background switching effect. When switching scenes, add the following test code to observe whether the background switching effect meets expectations.

```gdscript
bg.material.set("shader", your_effect_shader)

bg.material.set_shader_parameter("progress", 0.0)
bg.material.set_shader_parameter("current_texture", current_texture)
bg.material.set_shader_parameter("target_texture", tex)

# Create and configure transition animation
effect_tween = get_tree().create_tween()
effect_tween.tween_property(
	bg.material, 
	"shader_parameter/progress", 
	1.0, 
	1.0
)

effect_tween.play()
```

