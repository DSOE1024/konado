---
title: 액터 프레이밍
order: 5
---

# 액터 프레이밍

액터 프레이밍은 한 액터의 크기, 오프셋, 구도 중심만 조정합니다. 배경, 다른 액터, 스테이지 카메라는 움직이지 않습니다. 전체 화면 이동에는 `cam`을 사용하고, 같은 배경에서 특정 액터의 거리감을 바꿀 때 프레이밍을 사용하며 두 기능을 함께 사용할 수도 있습니다.

## 기본 프레이밍

Konado는 `default`, `full`, `medium`, `close`, `extreme_close`를 제공합니다. 스탠딩 이미지마다 크기와 얼굴 위치가 다르므로 상용 프로젝트에서는 필요한 캐릭터에 전용 `KonadoActorFramingProfile`을 설정하는 것이 좋습니다.

## KonadoScript

액터를 표시할 때 초기 프레이밍을 지정할 수 있습니다.

```text
actor show Kona normal at 3 [framing=medium]
```

이미 무대에 있는 액터의 프레이밍을 부드럽게 변경할 수도 있습니다.

```text
actor framing Kona close [duration=0.4] [transition=ease_in_out]
```

`transition`은 `linear`, `ease_in`, `ease_out`, `ease_in_out`을 지원합니다. 기본적으로 전환 완료를 기다립니다. `[wait=false]`를 사용하면 즉시 이야기를 계속하면서 여러 액터를 동시에 조정할 수 있습니다.

```text
actor framing Kona close [duration=0.4] [wait=false]
actor framing Mia medium [duration=0.4] [wait=false]
```

프레이밍은 액터의 지속 상태입니다. 상태 변경, 모션, 저장, 불러오기, 스토리 롤백 후에도 유지되며 새 요청은 완료되지 않은 이전 요청을 안전하게 대체합니다.

## 사용자 프리셋

Godot에서 `KonadoActorFramingProfile` 리소스를 만들고 `KonadoActorFramingPreset`을 추가한 뒤 캐릭터 정의의 `actor_framing_profile`에 할당합니다. 각 프리셋은 ID, 배율, 픽셀 오프셋, 정규화된 구도 중심, 기본 전환 시간과 이징을 설정합니다.

## 코드에서 호출

```gdscript
dialogue_manager.stage_controller.set_actor_framing("Kona", &"close", 0.4, "ease_in_out")
dialogue_manager.stage_controller.set_actor_framings({"Kona": "close", "Mia": "medium"}, 0.4)
```

일괄 API는 변경 전에 모든 액터와 프리셋을 검증하므로 일부만 적용되는 상태를 만들지 않습니다. Konado.NET에서는 `SetActorFraming()`과 `SetActorFramings()`를 사용할 수 있습니다.
