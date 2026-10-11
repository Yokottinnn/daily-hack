# asp-sync を 1 回 走らせる（t248・**$0**）

生成: **2026-10-11T12:31:31+0900**

| ASP | Keychain |
| --- | --- |
| a8 | **在る** |
| moshimo | **在る** |
| vc | **在る** |
| rakuten | **在る** |

```text
rakuten: ログインできていない / Keychain の ID・パスワードで入れなかった（値を確かめる）
```
rc=0 /      349 bytes
{
 "name": "楽天アフィリエイト",
 "loggedIn": false,
 "needsHuman": false,
 "credentialsInKeychain": true,
 "reason": "Keychain の ID・パスワードで入れなかった（値を確かめる）",
 "autoLoginTried": true,
 "url": "https://login.account.rakuten.com/sso/authorize?client_id=affiliate_jp_web&redirect_uri=https://affiliate.rakuten.co.jp/auth/callback&response_type=code&scope=openid%20profile&r10_required_claims=r10_name&ui_locales=ja-JP&state=22c729519f01e48310a894a32ddf184653129f5cda8ceab2e881e1ebc566b6ab#/sign_in/password",
 "title": "ログイン - 楽天",
 "formSeen": [
  "input[type=password name=password id=password_current]",
  "button「次へ」",
  "button「パスワードをお忘れの方」",
  "button「別の楽天IDでログイン」"
 ],
 "loginSteps": [
  {
   "label": "ID を打った直後",
   "url": "https://login.account.rakuten.com/sso/authorize?client_id=affiliate_jp_web&redirect_uri=https://affiliate.rakuten.co.jp/",
   "ins": [
    "text:username=20文字"
   ],
   "msgs": [],
   "btns": [
    "div[role=button]「次へ」",
    "a「関連規約類 (新規タブで開きます」",
    "a「個人情報保護方針 (新規タブで開」",
    "a「シークレットモードを使用 (新規」",
    "div[role=button]「パスワードをお忘れの方」",
    "a「楽天会員登録（無料）」",
    "a「ヘルプ」",
    "a「個人情報保護方針」",
    "a「会員規約」"
   ]
  },
  {
   "label": "「次へ」を押したあと",
   "url": "https://login.account.rakuten.com/sso/authorize?client_id=affiliate_jp_web&redirect_uri=https://affiliate.rakuten.co.jp/",
   "ins": [
    "password:password=0文字"
   ],
   "msgs": [],
   "btns": [
    "div[role=button]「次へ」",
    "div[role=button]「パスワードをお忘れの方」",
    "div[role=button]「別の楽天IDでログイン」",
    "a「ヘルプ」",
    "a「個人情報保護方針」",
    "a「会員規約」"
   ]
  },
  {
   "label": "パスワードを打った直後",
   "url": "https://login.account.rakuten.com/sso/authorize?client_id=affiliate_jp_web&redirect_uri=https://affiliate.rakuten.co.jp/",
   "ins": [
    "password:password=10文字"
   ],
   "msgs": [],
   "btns": [
    "div[role=button]「次へ」",
    "div[role=button]「パスワードをお忘れの方」",
    "div[role=button]「別の楽天IDでログイン」",
    "a「ヘルプ」",
    "a「個人情報保護方針」",
    "a「会員規約」"
   ]
  },
  {
   "label": "パスワードを送ったあと",
   "url": "https://login.account.rakuten.com/sso/authorize?client_id=affiliate_jp_web&redirect_uri=https://affiliate.rakuten.co.jp/",
   "ins": [
    "password:password=10文字"
   ],
   "msgs": [],
   "btns": [
    "div[role=button]「次へ」",
    "div[role=button]「パスワードをお忘れの方」",
    "div[role=button]「別の楽天IDでログイン」",
    "a「ヘルプ」",
    "a「個人情報保護方針」",
    "a「会員規約」"
   ]
  },
  {
   "label": "さらに 4 秒後",
   "url": "https://login.account.rakuten.com/sso/authorize?client_id=affiliate_jp_web&redirect_uri=https://affiliate.rakuten.co.jp/",
   "ins": [
    "password:password=10文字"
   ],
   "msgs": [],
   "btns": [
    "div[role=button]「次へ」",
    "div[role=button]「パスワードをお忘れの方」",
    "div[role=button]「別の楽天IDでログイン」",
    "a「ヘルプ」",
    "a「個人情報保護方針」",
    "a「会員規約」"
   ]
  }
 ]
}

## Keychain（dailyhack-asp-rakuten）
- ID の文字数: 20（@ を含む:  echo はい;; *) echo いいえ;; esac)）
- パスワードの文字数: 10
