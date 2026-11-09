# Mac が 11/9 02:54〜23:59 に止まった理由（2026-11-10 01:02 JST・読むだけ・$0）

## 1. 起動した時刻・再起動・ログイン
```
boottime: { sec = 1794237616, usec = 189849 } Tue Nov 10 00:20:16 2026
ny         console                         Tue Nov 10 00:20   still logged in
reboot time                                Tue Nov 10 00:20
shutdown time                              Tue Nov 10 00:19
ny         console                         Sat Sep 19 11:08 - 00:19 (51+13:11)
```

## 2. スリープ・復帰・電源断（11/9 02:00〜11/10 00:30）
```
2026-11-10 00:20:24 +0900 Start               	powerd process is started                                                  	          
```

## 3. 前回の電源断の理由（shutdown cause）
```
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t595-why-mac-stopped-1109.sh: line 10: 12521 Terminated: 15          "$@" > "$outf" 2>&1
（120 秒で打ち切った）
```

## 4. パニック・電源の記録ファイル（11/9 のもの）
```
-rw-rw----@  1 root  _analyticsusers  1320796 Nov 10 00:23 shutdown_stall_2026-11-10-002000_NaokinoMacBook-Pro-2.shutdownStall
（無ければ空）
```

## 5. 電源の設定（自動スリープ・停電後の再起動）
```
 standby              1
 hibernatefile        /var/vm/sleepimage
 powernap             1
 networkoversleep     0
 disksleep            0
 sleep                0 (sleep prevented by caffeinate, caffeinate, powerd)
 displaysleep         10 (display sleep prevented by caffeinate)
 womp                 1
Now drawing from 'AC Power'
 -InternalBattery-0 (id=7143523)	100%; charged; 0:00 remaining present: true
```
