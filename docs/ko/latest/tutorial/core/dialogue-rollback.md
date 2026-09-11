---
title: 대화 되돌리기 (이전 대사)
order: 9
---

# 대화 되돌리기 (이전 대사)

대화 되돌리기는 플레이어를 **이전** 표시 줄(대사·선택지·전체 화면 텍스트)로 되돌리고 그 지점부터 이어서 진행합니다. 기본 대화 템플릿은 기능 표시줄에 "이전" 버튼을 제공합니다.

## 런타임 API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# 되돌릴 수 있는지(도달 가능한 이전 줄이 있고 경계에 막히지 않았는지)
var can: bool = dialogue_manager.timeline.can_step_back()

# 이전 줄로 되돌리기. 성공 시 true
if dialogue_manager.timeline.can_step_back():
    dialogue_manager.timeline.step_back()

# 되돌리는 데 필요한 커밋된 명령 수(0이면 불가)
var steps: int = dialogue_manager.timeline.previous_dialogue_steps()

# Backlog 항목 되돌리기: 항목이 가진 VM 커밋 일련번호로 바로 조회/실행
var reachable: bool = dialogue_manager.timeline.can_rollback_to_entry(serial)
dialogue_manager.timeline.rollback_to_entry(serial)
```

## 원자성

되돌리기는 가상 머신의 **가역 트랜잭션 롤백**을 재사용하고, 추가로 목표 줄의 **전체 스냅샷**으로 장면을 복원한 뒤 결정론적으로 재생합니다.

- 진행 중인 트랜잭션(타이핑·보이스·대기 중 비동기 작업)을 취소하고 토큰을 무효화합니다;
- 스냅샷이 카메라·배우·배경·오디오·UI·변수를 정확히 복원합니다(명령별 증분 누적에 의존하지 않으므로 비동기 카메라와 트랜지션이 있는 연출도 정확히 되돌립니다. 최근 128줄 보관);
- 재생이 **같은 프레임 안에서** 끝난 뒤에 화면이 갱신되므로, 이전 화면이 잠깐 보이는 일이 없습니다;
- 복원에 실패하면 안전 정지 상태로 들어가며, 반쯤 복원된 화면을 남기지 않습니다.

## 경계

경계가 되는 것은 `end`(`halt`)뿐입니다. `jump`(`jump.script`)는 **넘어갈 수 있습니다**: 되돌리기는 그 줄이 속한 스크립트까지 함께 복원하므로 "이전 줄"은 이동해 온 스크립트로 돌아가고, 그대로 진행하면 `jump`가 다시 실행됩니다.

넘어갈 수 있는 부작용: `signal`과 `asyncam`은 재생이 그 지점을 지날 때 **다시 실행**됩니다(신호는 재발생하고 카메라는 다시 움직입니다). 따라서 다시 고른 분기에서는 신호 핸들러가 재호출됩니다. 업적 명령(`achievement unlock` / `increment` / `set_flag`)은 외부 카운터라 넘어갈 수는 있지만 **재생되지 않습니다**(업적은 회수되지도, 두 번 누적되지도 않습니다). 비동기 카메라는 되돌릴 때 진행 중인 Tween을 취소하고 스냅샷에서 변환을 복원합니다. 핸들러가 **스냅샷 밖**의 상태를 수정한다면 멱등하게 만드세요(「변수와 부작용」 참고).

다음 경우에는 여전히 되돌리기가 **거부**됩니다(`can_step_back()`가 `false`).

- 이전 줄 앞에 `end`(`halt`)가 있는 경우;
- 처리되지 않은 런타임 오류가 있는 경우;
- 실행 기록이 비워졌거나 보존 용량(기본 512개 명령)을 초과한 경우, 또는 필요한 줄의 스냅샷이 이미 제거된 경우(스냅샷 캐시는 최근 128줄을 4 MiB 예산 안에서 유지합니다).

## 분기 되돌리기

이전 줄이 **선택지**이면 되돌릴 때 모든 선택지가 다시 표시되어 다시 고를 수 있습니다.

```gdscript
dialogue_manager.timeline.step_back()  # 선택지가 다시 나타남
```

다시 고르면 새 선택 기록이 남습니다. 기본 `TRIM` 정책에서는 버려진 선택이 기록에서 제거되고, `KEEP`에서는 둘 다 남습니다.

한 번 더 되돌리면 질문 대사의 **이전** 줄로 이동합니다. 선택지는 대사창 텍스트를 바꾸지 않으므로 선택지가 겹쳐 있는 줄은 이미 화면에 있으며, 아무 변화도 없는 클릭을 만들지 않도록 한 번에 건너뜁니다. 취소된 선택지 표시도 함께 제거되므로 이전 대사 위에 버튼이 남지 않습니다.

## Backlog 점프(원하는 줄로 되돌리기)

기본 템플릿의 Backlog 패널은 **아무 줄이나 클릭해 그 줄로 되돌릴 수 있습니다** — Ren'Py의 기록 화면은 읽기 전용이라 점프하려면 직접 코드를 써야 합니다:

```gdscript
# Backlog 항목은 대응하는 VM 커밋 일련번호를 가집니다
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# 그 항목이 되돌리기 대상이 될 수 있는지
if dialogue_manager.timeline.can_rollback_to_entry(entries[0]["serial"]):
    # 그 줄로 되돌리기: "이전 줄"과 같은 원자 경로를 사용합니다
    dialogue_manager.timeline.rollback_to_entry(entries[0]["serial"])
```

의미론은 "이전 줄"과 완전히 같습니다: 그 줄의 스냅샷으로 장면을 복원하고, 같은 프레임에서 재생하며, 스크립트를 넘는 `jump`도 넘어갈 수 있고, 넘어간 되돌릴 수 없는 부작용은 정책을 따르며, 복원 실패 시 안전 정지로 들어갑니다.

되돌릴 수 없는 항목:

- **지금 표시 중인 줄**(아직 커밋되지 않음, 일련번호 0) — 패널에서는 표시만 하며 클릭할 수 없습니다;
- 유효하지 않은 일련번호, 또는 스냅샷이 보존 범위(최근 128줄, "경계" 참고)를 벗어난 줄.

되돌린 뒤에는 패널 기록도 대상 줄까지 잘리고, 계속 진행하면 넘어간 재생 가능한 부작용(`signal`)이 다시 실행되므로 최종 상태는 첫 플레이와 같습니다.

## 변수와 부작용

되돌리기가 되감는 것은 **스냅샷 안의 상태**(스크립트 변수, 카메라, 액터, 배경, 오디오, UI, 실행 위치)뿐입니다. 나머지는 아래 규칙을 따릅니다:

| 기록 대상 | 되돌릴 때 | 재생이 그 명령을 지날 때 |
| --- | --- | --- |
| `$` 임시 변수 / `%` 영구 변수(`set`, `add` 등) | 대상 줄로 정확히 복원(스냅샷은 집합 전체를 교체하므로 이후에 만든 변수도 제거됩니다) | 정상적으로 다시 실행 |
| `signal` | 핸들러가 **스냅샷 안**에 가한 변경도 줄과 함께 되감깁니다 | **재발생**하며 핸들러가 다시 실행됩니다 |
| `achievement unlock` / `increment` / `set_flag` | 취소되지 않음(업적은 늘어나기만 합니다) | **재생되지 않음**(두 번 집계되지 않음) |
| 스냅샷 밖의 상태(싱글턴, 외부 세이브, 사용자 Resource) | 되돌릴 수 없음 | 핸들러 쪽에서 멱등하게(예 3 참고) |

**영구 변수(`%`)와 임시 변수(`$`)는 모두 스냅샷 안**에 있으므로, 되돌리기는 대상 줄의 상태로 통째로 복원합니다. 차이는 "언제 바뀌는가"입니다:

- `%` 영구 변수는 씬(`jump`)을 넘어도 유지되고 세이브에도 저장됩니다. 되돌리기는 **대상 줄 시점의 값**으로 되돌립니다.
- `$` 임시 변수는 씬이 바뀔 때(`jump`) 비워집니다. 되돌리기는 대상 줄 시점의 값으로 되돌리므로, 스크립트를 넘어 되돌리면 이전 스크립트의 임시 변수가 다시 나타납니다.

> ⚠️ `%`는 대상 줄의 스냅샷으로 **집합 전체가 교체**되므로, 그 두 줄 사이에 대화 밖(상점, 메뉴, `variable_store`를 직접 쓰는 외부 코드)에서 바뀐 `%` 값도 함께 되감깁니다. 이는 시간 역행 의미론입니다. 되돌리기의 영향을 받으면 안 되는 수치(플랫폼 재화, 계정 진행도)는 `%`가 아니라 Konado 스냅샷 밖에 두세요.

### 예 1: 수치는 스크립트 변수에 두기(권장)

```text
set %love = 0
Kona "기초 튜토리얼을 시작할까요?"
choice "기초 튜토리얼 시작" -> start_choice
choice "나중에" -> exit_choice

branch start_choice
    add %love 1
    Kona "함께 배워 봐요!"
    end
```

선택지까지 되돌린 뒤 같은 분기를 다시 고르면: `%love`는 먼저 스냅샷으로 `0`으로 복원되고, 재생에서 `add %love 1`이 한 번 더 실행됩니다 → 결과는 여전히 `1`입니다. `2`로 남지도, 사라지지도 않습니다.

### 예 2: `signal` + 스냅샷 안만 수정하는 핸들러

동봉 데모가 쓰는 방식입니다(`sample/demo/demo.gd`):

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content == "호감도 상승":
        # Konado 영구 변수를 수정: 스냅샷 안의 상태
        dialogue_manager.variable_store.apply_operation(
            "love", KonadoVariableStore.Operation.ADD, 1
        )
```

```text
choice "기초 튜토리얼 시작" -> start_choice

branch start_choice
    ...
    signal 호감도 상승
    Kona "이용해 주셔서 감사합니다!"
    jump res://sample/demo/demo_02.ks
```

그 분기를 넘어 되돌린 뒤 다시 고르면: 신호가 **재발생**해 핸들러가 다시 `+1`하고, 핸들러가 쓴 `%love`도 줄과 함께 되감겨 있습니다. 따라서 순 결과는 `+1` 그대로입니다(`+2`도, `0`도 아닙니다).

### 예 3: `signal` + 스냅샷 밖을 수정하는 핸들러(멱등 필수)

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "갤러리 해금":
        return
    # 스냅샷 밖 시스템만 건드립니다: 되돌리기로 복원할 수 없습니다
    external_save.unlock_gallery("cg_01")
```

이 명령을 넘어 되돌리면 신호가 재발생해 `unlock_gallery`가 다시 호출됩니다. 원래부터 멱등하게 만들거나, **스냅샷 안의 변수**를 가드로 쓰세요:

```gdscript
func _on_konado_custom_signal(content: Variant) -> void:
    if content != "갤러리 해금":
        return
    if dialogue_manager.variable_store.get_bool("gallery_cg_01"):
        return
    dialogue_manager.variable_store.set_value("gallery_cg_01", true)
    external_save.unlock_gallery("cg_01")
```

> 되돌리기를 완전히 예측 가능하게 하려면 **권위 있는 수치**를 `%` 영구 변수나 `$` 임시 변수에 두고, 외부 시스템은 표현 계층(사운드, UI, 플랫폼 업적 동기화)으로 한정해 몇 번 호출해도 안전하게 만드세요.

### 업적은 재생되지 않음

`achievement unlock` / `achievement increment` / `achievement set_flag`는 외부 카운터입니다. 되돌리기로 넘어갈 수는 있지만 재생 시 **다시 실행되지 않습니다** — 업적은 회수되지도, 두 번 기록되지도 않습니다. 되돌린 뒤 다시 발동해야 하는 것은 스크립트 변수로 표현하세요.

## 세이브와 기록

되돌리기는 메모리 내 작업이며 세이브 형식을 바꾸지 않습니다. 기록 정리는 `KonadoDialogueHistory.RollbackPolicy`를 따릅니다("대화 기록" 참고).
