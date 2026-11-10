# Mac が 11/9 に固まった理由（2026-11-11 01:03 JST・読むだけ・$0）

## 1. 11/8〜11/10 の診断の記録ファイル（種類と大きさ）
```
7769 Nov 8 00:25 Google
37846 Nov 9 00:26 Google
47422 Nov 9 00:26 Google
58847 Nov 9 00:26 Google
7430 Nov 9 00:26 The
374104 Nov 8 00:25 disk
340089 Nov 9 00:26 disk
390530 Nov 10 00:23 disk
1320796 Nov 10 00:23 shutdown_stall_2026-11-10-002000_NaokinoMacBook-Pro-2.shutdownStall
664 Nov 9 06:21 SFA-CloudServices.json_2026-11-09-062119_NaokinoMacBook-Pro-2.diag
17209 Nov 9 18:20 SFA-ckks.json_2026-11-09-182051_NaokinoMacBook-Pro-2.diag
390 Nov 10 18:20 SFA-local.json_2026-11-10-182052_NaokinoMacBook-Pro-2.diag
436 Nov 10 18:20 SFA-networking.json_2026-11-10-182050_NaokinoMacBook-Pro-2.diag
1180 Nov 8 06:21 SFA-pcs.json_2026-11-08-062122_NaokinoMacBook-Pro-2.diag
1180 Nov 9 06:21 SFA-pcs.json_2026-11-09-062121_NaokinoMacBook-Pro-2.diag
1180 Nov 10 18:20 SFA-pcs.json_2026-11-10-182052_NaokinoMacBook-Pro-2.diag
2467 Nov 10 18:20 SFA-rootNetworking.json_2026-11-10-182050_NaokinoMacBook-Pro-2.diag
388 Nov 8 18:20 SFA-sos.json_2026-11-08-182055_NaokinoMacBook-Pro-2.diag
388 Nov 9 18:20 SFA-sos.json_2026-11-09-182051_NaokinoMacBook-Pro-2.diag
93876 Nov 8 12:20 proactive_event_tracker-com_apple_Trial-com_apple_triald_2026-11-08-122043_NaokinoMacBook-Pro-2.diag
141527 Nov 9 12:20 proactive_event_tracker-com_apple_Trial-com_apple_triald_2026-11-09-122053_NaokinoMacBook-Pro-2.diag
71205 Nov 10 12:21 proactive_event_tracker-com_apple_Trial-com_apple_triald_2026-11-10-122111_NaokinoMacBook-Pro-2.diag
4479 Nov 8 12:20 proactive_event_tracker-com_apple_Trial-com_apple_triald_system_2026-11-08-122044_NaokinoMacBook-Pro-2.diag
4479 Nov 9 12:20 proactive_event_tracker-com_apple_Trial-com_apple_triald_system_2026-11-09-122053_NaokinoMacBook-Pro-2.diag
1933 Nov 10 12:21 proactive_event_tracker-com_apple_Trial-com_apple_triald_system_2026-11-10-122113_NaokinoMacBook-Pro-2.diag
```

## 2. 終了処理が止まった記録（shutdownStall）の先頭と、止まっていたプロセス
```
Use spindump -i to generate textual report

Spindump binary format
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
--- プロセス名の出現回数（多い順・上位 20）
```

## 3. 固まる前後の macOS の記録（11/9 02:40〜03:10・エラーと警告の多いプロセス）
```
行数: 10223
--- プロセスごとの件数（上位 15）
3950 
2168 imagent
1243 TrialArchivingService
 711 assetsubscriptiond
 217 end:WarnOnly
 214 sourceEnvironment:"(null)">
 128 entitlements:<RBEntitlements|
 124 apsd
 104 sourceEnvironment:"(null)">,
  87 hash:
  80 SAExtensionOrchestrator
  43 dasd
  39 mobileassetd
  37 Policy,
  36 businessservicesd
--- メモリ・ウォッチドッグ・ディスクの行（最後の 25 行）
	]> intransientState:<RBAssertionIntransientState| strt:Unspecified end:WarnOnly nvld:0.00 warn:0.00dom runningReason:0 legRes:0 doms:com.apple.webkit:BoostedJetsam invOnConds:(null)> processState:<RBProcessState| role:N
	<RBSDomainAttribute| domain:"com.apple.webkit" name:"BoostedJetsam" sourceEnvironment:"(null)">
<RBAssertion| identifier:178-561-894 target:[xpcservice<com.apple.WebKit.GPU([app<application.com.apple.mail.1152921500311886815.1152921500311886820(501)>:561])(501)>{vt hash: 0}[uuid:570C8D31-0D07-45FE-91EB-C2AF0C2D5058
	]> intransientState:<RBAssertionIntransientState| strt:Unspecified end:WarnOnly nvld:0.00 warn:0.00dom runningReason:0 legRes:0 doms:com.apple.webkit:BoostedJetsam invOnConds:(null)> processState:<RBProcessState| role:N
	<RBSDomainAttribute| domain:"com.apple.webkit" name:"BoostedJetsam" sourceEnvironment:"(null)">
			]> inheritanceManager:<RBClientInheritanceManager| >><RBAssertion| identifier:178-15774-2176691 target:[xpcservice<com.apple.WebKit.GPU([anon<Google Drive>(501):15774])(501)>{vt hash: 0}[uuid:A80CC077-5C1B-441F-839A-4
	]> intransientState:<RBAssertionIntransientState| strt:Unspecified end:WarnOnly nvld:0.00 warn:0.00dom runningReason:0 legRes:0 doms:com.apple.webkit:BoostedJetsam invOnConds:(null)> processState:<RBProcessState| role:N
	<RBSDomainAttribute| domain:"com.apple.webkit" name:"BoostedJetsam" sourceEnvironment:"(null)">
			]> inheritanceManager:<RBClientInheritanceManager| >><RBAssertion| identifier:178-559-319 target:[xpcservice<com.apple.WebKit.GPU([app<application.com.apple.Passwords.1152921500311894801.1152921500311894829(501)>:559]
	]> intransientState:<RBAssertionIntransientState| strt:Unspecified end:WarnOnly nvld:0.00 warn:0.00dom runningReason:0 legRes:0 doms:com.apple.webkit:BoostedJetsam invOnConds:(null)> processState:<RBProcessState| role:N
	<RBSDomainAttribute| domain:"com.apple.webkit" name:"BoostedJetsam" sourceEnvironment:"(null)">
			]> inheritanceManager:<RBClientInheritanceManager| >><RBAssertion| identifier:178-15774-2176693 target:[xpcservice<com.apple.WebKit.Networking([anon<Google Drive>(501):15774])(501)>{vt hash: 0}[uuid:31612754-1B11-44F4
	]> intransientState:<RBAssertionIntransientState| strt:Unspecified end:WarnOnly nvld:0.00 warn:0.00dom runningReason:0 legRes:0 doms:com.apple.webkit:BoostedJetsam invOnConds:(null)> processState:<RBProcessState| role:N
	<RBSDomainAttribute| domain:"com.apple.webkit" name:"BoostedJetsam" sourceEnvironment:"(null)">
	]><RBAssertion| identifier:178-561-896 target:[xpcservice<com.apple.WebKit.Networking([app<application.com.apple.mail.1152921500311886815.1152921500311886820(501)>:561])(501)>{vt hash: 0}[uuid:E9AF8F56-2FE7-4E49-9921-1E
	]> intransientState:<RBAssertionIntransientState| strt:Unspecified end:WarnOnly nvld:0.00 warn:0.00dom runningReason:0 legRes:0 doms:com.apple.webkit:BoostedJetsam invOnConds:(null)> processState:<RBProcessState| role:N
	<RBSDomainAttribute| domain:"com.apple.webkit" name:"BoostedJetsam" sourceEnvironment:"(null)">
			]> inheritanceManager:<RBClientInheritanceManager| >><RBAssertion| identifier:178-561-1059 target:[xpcservice<com.apple.WebKit.WebContent([app<application.com.apple.mail.1152921500311886815.1152921500311886820(501)>:5
	]> intransientState:<RBAssertionIntransientState| strt:Unspecified end:WarnOnly nvld:0.00 warn:0.00dom runningReason:0 legRes:0 doms:com.apple.webkit:BoostedJetsam invOnConds:(null)> processState:<RBProcessState| role:N
	<RBSDomainAttribute| domain:"com.apple.webkit" name:"BoostedJetsam" sourceEnvironment:"(null)">
2026-11-09 03:06:01.611 Df dasd[148:451c72b] [com.apple.duetactivityscheduler:scoring] 0:com.apple.memory-maintenance.report-jetsam-telemetry:133B50:[
2026-11-09 03:06:29.825 Df dasd[148:451ca18] [com.apple.duetactivityscheduler:scoring] 0:com.apple.memory-maintenance.report-jetsam-telemetry:133B50:[
2026-11-09 03:07:32.881 Df dasd[148:451cd24] [com.apple.duetactivityscheduler:scoring] 0:com.apple.memory-maintenance.report-jetsam-telemetry:133B50:[
2026-11-09 03:08:37.682 Df dasd[148:451d45c] [com.apple.duetactivityscheduler:scoring] 0:com.apple.memory-maintenance.report-jetsam-telemetry:133B50:[
2026-11-09 03:09:44.828 Df dasd[148:451d847] [com.apple.duetactivityscheduler:scoring] 0:com.apple.memory-maintenance.report-jetsam-telemetry:133B50:[
--- 記録の最後の 15 行（ここで止まった）
2026-11-09 03:08:13.399 F  apsd[138:9be] [com.apple.apsd:connectionServer] Peer [pid=464] attempts to set ultra constrained topics without ultra constrained enabled entitlement
2026-11-09 03:08:13.400 F  apsd[138:9be] [com.apple.apsd:connectionServer] Peer [pid=464] attempts to set ultra constrained topics without ultra constrained enabled entitlement
2026-11-09 03:08:37.682 Df dasd[148:451d45c] [com.apple.duetactivityscheduler:scoring] 0:com.apple.memory-maintenance.report-jetsam-telemetry:133B50:[
	{name: Device Activity Policy, policyWeight: 20.000, response: {33, 0.00, [{deviceActivity == 4}]}}
 ], Decision: MNP}
2026-11-09 03:08:37.916 E  searchpartyd[358:451d106] [com.apple.accounts:core] "Remote account store returned fatal error: Error Domain=NSCocoaErrorDomain Code=4099 "The connection to service named com.apple.accountsd.ac
2026-11-09 03:08:37.918 E  searchpartyd[358:451d106] [com.apple.accounts:core] "Remote account store returned fatal error: Error Domain=NSCocoaErrorDomain Code=4099 "The connection to service named com.apple.accountsd.ac
2026-11-09 03:08:37.920 E  searchpartyd[358:451d442] [com.apple.authkit:traffic] Remote Anisette service returned an error: Error Domain=NSCocoaErrorDomain Code=4099 UserInfo={NSDebugDescription=<private>}
2026-11-09 03:08:37.920 E  searchpartyd[358:451d442] [com.apple.authkit:traffic] Attestation fetch failed with XPC error, retrying...
2026-11-09 03:08:37.921 E  searchpartyd[358:451d442] [com.apple.authkit:traffic] Remote Anisette service returned an error: Error Domain=NSCocoaErrorDomain Code=4099 UserInfo={NSDebugDescription=<private>}
2026-11-09 03:08:37.921 E  searchpartyd[358:451d442] [com.apple.authkit:traffic] Unable to append header for request <private>! Task LocalDataTask <1C2C4CBB-969D-4B20-9529-AFA5495590F5>.<1> Error: Error Domain=NSCocoaErr
2026-11-09 03:09:31.003 E  dasd[148:451d7f7] [com.apple.duetactivityscheduler:energybudgeting] PowerLog Update: nil response
2026-11-09 03:09:44.828 Df dasd[148:451d847] [com.apple.duetactivityscheduler:scoring] 0:com.apple.memory-maintenance.report-jetsam-telemetry:133B50:[
	{name: Device Activity Policy, policyWeight: 20.000, response: {33, 0.00, [{deviceActivity == 4}]}}
 ], Decision: MNP}
```

## 4. いまのメモリと空き容量（比べるため）
```
Pageouts: 248108 

System-wide memory free percentage: 42%
vm.swapusage: total = 7168.00M  used = 5574.38M  free = 1593.62M  (encrypted)
/dev/disk3s1s1   460Gi    12Gi    88Gi    12%    455k  925M    0%   /
```
