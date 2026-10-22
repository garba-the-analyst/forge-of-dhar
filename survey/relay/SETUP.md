# Setting up direct delivery (the relay)

With the relay switched on, a respondent presses **Send my answers** and the survey page posts the answers and the PDF copy to a small Google Apps Script that **you** run. The script does two things with every response:

1. **Emails it to you**, PDF attached. If the respondent gave an email address, it is the **Reply-To** of the message, so pressing Reply in Gmail writes to them.
2. **Saves it in a Google Sheet** on your account: one row per response, one column per question code, plus a sheet with the wording of every question. This is the record you analyse, and the safety net: if the email cannot be sent (for example the daily mail limit), the response is still saved and the respondent still sees "sent".

It takes about ten minutes, once, on a computer. (A phone can do it if you open script.google.com with "Desktop site" ticked in the browser menu, but the editor is hard to use on a small screen.)

## What it is, and what it is not

| | |
|---|---|
| **Who sends the email** | Your own Gmail account, with the display name "Shaping Dhar survey". The message lands in your inbox. |
| **"From" the respondent?** | No, and no website can do that: mail "from" someone's address has to be sent by their own mail provider. The respondent's address is in **Reply-To** and written in the message. |
| **Where the data lives** | In your inbox and in the spreadsheet **Shaping Dhar responses** in your Google Drive. Both are private to you unless you share them. The script keeps nothing else: it remembers response IDs and a counter for a few hours so a retry is not recorded twice. |
| **Cost** | Free. A free Gmail account may send about 100 emails a day through Apps Script (Google's published quota, which can change). Google Workspace accounts get more. The sheet has no such small limit. |
| **When it fails** | If both the email and the sheet fail, the page tells the respondent and offers the email-draft route (the way the survey worked before). If only one fails, the respondent sees "sent" and the other record exists. |

## Steps

### 1. Create the script
1. Open <https://script.google.com> and sign in with the Gmail account that should **receive** the responses.
2. Choose **New project**. Click the name at the top and rename it **Shaping Dhar relay**.
3. In the editor you will see a file called `Code.gs` with a few lines in it. Select all of it and delete it.
4. Open `relay/Code.gs` from this repository (<https://github.com/garba-the-analyst/forge-of-dhar/blob/gh-pages/relay/Code.gs>), press **Raw**, select all, copy, and paste it into the editor.
5. Press **Save** (the disk icon, or Ctrl+S).

### 2. Test the sending and the log
1. In the toolbar, use the function dropdown (it may say `myFunction`) and pick **selfTest**.
2. Press **Run**. Google asks for permission:
   - **Review permissions**, choose your account.
   - You will see **"Google hasn't verified this app"**. That is expected: it is your own script and it has not been through Google's public review. Press **Advanced**, then **Go to Shaping Dhar relay (unsafe)**.
   - The permissions are: *send email as you*, *see, edit, create and delete your Google Sheets spreadsheets*, and *see your primary Google Account email address*. The script uses them to email responses, to write the log sheet, and to find your address. It does not touch Drive files other than the spreadsheets, and it does not read your mail.
3. After a few seconds the log at the bottom says `Self test passed` and prints the address of the log sheet. Check your inbox for **"[TEST] Shaping Dhar survey response: self test"** with a small PDF attached (look in **Spam** once; if it is there, press **Not spam**), and open the sheet link: **Responses** has one row with status `test-emailed`.

If `selfTest` fails, the log says why. Common causes: you did not approve the permissions, or the account's daily mail limit is used up.

### 3. Publish it as a web app
1. Press **Deploy**, then **New deployment**.
2. Press the gear next to "Select type", and choose **Web app**.
3. Fill in:
   - **Description:** `Shaping Dhar relay 1.0`
   - **Execute as:** **Me** (your address)
   - **Who has access:** **Anyone**   *(not "Anyone with Google account": respondents are not signed in)*
4. Press **Deploy**. Copy the **Web app URL**. It looks like `https://script.google.com/macros/s/AKfy.../exec`.

If "Anyone" is not offered, your account is probably a school or company (Workspace) account whose administrator restricts it. Use a personal Gmail account for the relay instead.

### 4. Tell the survey about it
Send me the URL and I will put it in. Or do it yourself: open `assets/config.js` in the repository, set

```js
relayUrl: 'https://script.google.com/macros/s/AKfy.../exec',
```

and commit. GitHub Pages updates in about a minute. (`relayToken` already matches `CONFIG.TOKEN` in `Code.gs`; leave both as they are.)

### 5. Check it from the real site
Open **<https://garba-the-analyst.github.io/forge-of-dhar/relay-check.html>** and press the two buttons:

* **Check the relay**: green means the web address is right and the browser may read the relay's answer.
* **Send a test response**: green means a `[TEST]` email with a PDF is on its way and a row marked `test-emailed` was added to the log. It should arrive within a minute.

If either button is red, the page explains the likely cause. Then do one real run through the survey yourself, and press **Send my answers** at the end. (Delete the test rows in the sheet before you start collecting: filter `status` for `test-`.)

### 6. Keep responses out of Spam and easy to find (recommended)
In Gmail, search `subject:"Shaping Dhar survey response"`, open the search options (the sliders icon), press **Create filter**, and tick **Never send it to Spam**, **Apply the label** (make one called `Dhar survey`) and, if you like, **Star it**.

## Reading the responses

**The sheet is the quickest way.** Open **Shaping Dhar responses** in your Google Drive (the address was printed by `selfTest`; it is also remembered in the script's properties).

* **Responses**: one row per response. The first columns are `received_utc`, `response_id`, `survey_version`, `submitted`, `roles`, `answered`, `reply_to`, `pdf_copy`, `status` and `response_text` (the whole response as sent). After those come one column per question code (`A1`, `A3`, `P3`, ...), added the first time a code appears. Single answers are the option text, multiple choices are joined with ` | `, scales are numbers, grids are `statement: number` pairs.
* **Questions**: the code, survey version and wording of every question, so the codes are readable on their own. `docs/CODEBOOK.md` in the repository lists the same.
* `status` is `emailed` (both worked), `stored` (the email could not be sent; the response is only in the sheet) or has a `test-` prefix for test messages.
* A typed answer that starts with `=`, `+`, `-` or `@` is stored with a leading apostrophe, which Sheets hides, so a respondent cannot plant a formula in your sheet.
* Answers longer than 45,000 characters are cut in their cell with a note. The email always has the complete text.

**The emails still work with the parser.** To rebuild a CSV from the mailbox (for example as a second copy), export the `Dhar survey` label (Google Takeout gives an `.mbox` file), or save emails as `.eml`, and run:

```
python3 tools/parse_responses.py responses.mbox -o responses.csv
```

Every response has a reference such as `dhar-20261019-154500-k3x9ab`. If one reaches you twice (relay and email) the parser keeps one row. The log and the parser read responses the same way; the tests check that they agree.

**Back up the sheet** from time to time: in the sheet, **File > Download > Comma-separated values** for each sheet, or **File > Make a copy**.

## Changing things later

| I want to... | Do this |
|---|---|
| Change the code | Edit it in the script editor, then **Deploy > Manage deployments > pencil > Version: New version > Deploy**. The URL stays the same. |
| Send responses to another address | Set `RECIPIENT` near the top of `Code.gs`, then deploy a new version. |
| Use a spreadsheet I made myself | Set `LOG_SPREADSHEET_ID` in `Code.gs` to the long ID in its web address, then deploy a new version. |
| Stop saving to the sheet | Set `LOG_TO_SHEET` to `false`, then deploy a new version. (An exhausted mail quota then sends respondents to the email-draft route again.) |
| Switch the relay off | Set `relayUrl: ''` in `assets/config.js`. The survey goes back to the email-draft route. |
| Stop the script answering at all | **Deploy > Manage deployments > Archive**, or delete the project. |
| Change the token | Change `TOKEN` in `Code.gs` and `relayToken` in `config.js` to the same new value, and deploy a new version. The token is visible in the page source, so it only stops stray requests. It is not a password. |
| Allow more per hour | Raise `MAX_PER_HOUR` in `Code.gs` (default 40), deploy a new version. |
| See what the script did | In the script editor, **Executions** lists every run with its time and any error message. It never contains answers. |

## What happens at the limits
* **Over about 100 emails in a day (free Gmail):** the script stops emailing when 5 remain, and keeps saving to the sheet. Respondents still see "sent".
* **Over 40 attempts in an hour:** the script answers "too many" and the page offers the respondent the email-draft route. Raise `MAX_PER_HOUR` if you expect a burst, for example a class filling the survey at once.
* **Someone posts junk to the web address:** it is refused unless it has the token, is under the size limit, and looks like a survey response (the shape check). A flood is slowed by the hourly limit. Nothing but a valid response ever becomes an email or a row.

## What has and has not been verified
* `Code.gs` is tested with `node relay/test/relay_test.js` (309 checks) against an imitation of the Google services (mail, cache, lock, properties and spreadsheets, including a sheet's 26-column start and its refusal of out-of-range writes), and together with the survey page by the browser tests (`python3 tests/run_tests.py`), which run the real `Code.gs` behind `relay/test/mock_apps_script.js`, a local server that behaves like an Apps Script web app (a redirect to another address, CORS headers on the answer, no answer to a pre-flight).
* The imitation follows Google's documentation. It has **not** been run against real Google servers from here. Things only the real service can confirm, which is why steps 2 and 5 exist: that a page on github.io may **read** the relay's answer, that Google accepts the attachment and Reply-To exactly as documented, and that Sheets keeps a leading apostrophe as a text marker when written by a script. If the page cannot read the answer, the survey says it could not confirm delivery and offers the email route; the response may still have arrived, and a repeat is ignored by its reference.
