@abstract class_name CombatAction extends RefCounted
## ③ Domain：ActionQueue に積まれる 1 つの処理。スケジューリングだけを担い、ルールは効果と Combat の API にある。


@abstract func execute(combat: Combat) -> ActionQueue.Step
