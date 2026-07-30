---
title: 대화 상자 사용자 지정
order: 4
---

# 대화 인터페이스 사용자 지정

## 소개

대화 인터페이스를 사용자 지정하려면 사용할 템플릿 씬을 `res://ui/dialogue/` 같은 프로젝트 전용 디렉터리로 먼저 복사한 뒤, 그 사본이나 Godot 사용자 지정 테마를 편집하세요.

`res://addons/konado/` 아래 파일을 직접 수정하지 마세요. 플러그인 업그레이드는 플러그인 디렉터리를 교체합니다. 프로젝트 소유 사본은 Konado를 업그레이드해도 유지됩니다.

## 템플릿 파일 편집

`res://addons/konado/template/`에는 기본 대화 템플릿이 있습니다. 필요한 `.tscn`을 프로젝트로 복사하고 대화 씬에서 그 사본을 인스턴스화한 다음, 포함된 `KND_DialogueBox` 노드를 `KND_DialogueManager`의 `_konado_dialogue_box` 속성에 할당하세요.

일반적으로 노드의 스크립트는 수정하지 말고, 노드의 속성을 수정해 사용자 지정 효과를 구현하세요.

## 음성 진행 표시 사용자 지정

일반 대사에 음성 태그가 있고 오디오가 재생 중이면 대화 상자에 재생 진행 상태가 표시됩니다. 음성이 없거나 리소스를 확인할 수 없거나 재생이 끝나면 자동으로 숨겨집니다. 필요하지 않다면 `KonadoDialogueBox` 노드의 `show_voice_progress`를 끄세요.

기본 컴포넌트 원본은 `res://addons/konado/template/default/voice_progress_display.tscn`입니다. 색상, 둥근 모서리, 크기 또는 노드 구조를 수정하기 전에 프로젝트로 복사하고 사용자 지정 대화 상자에서 그 사본을 참조하세요. 완전히 교체할 때는 다음 인터페이스를 유지해야 합니다.

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```
