# Security Policy

## Reporting a vulnerability

Report security bugs and vulnerabilities to
**[shain.singh@owasp.org](mailto:shain.singh@owasp.org)** — or use GitHub's private
vulnerability reporting: [Report a vulnerability](https://github.com/kailash-os/kailash-os/security/advisories/new).
Do not open a public issue for an unreported vulnerability.

Email reports may be encrypted to the OpenPGP key below. Include a description of
the issue, steps to reproduce, and the affected version or commit. Reports are
triaged within a few days; accepted issues receive a fix and a release. Honour
responsible disclosure until an advisory is published.

## Scope and authorised use

Kailash **ships offensive AI-security tooling for authorised security work
only** — red-team engagements with written authorisation, academic research,
and defender validation of one's own systems. Tooling misuse is not a
vulnerability in Kailash; build/safety defects that let tooling escape its
gates *are*.

High-value vulnerability classes here:

- **Safety-gate bypass** — anything that lets an active-exploit tool run
  without the double gate (explicit host opt-in + explicit shell opt-in), or
  that flips `KAILASH_LAB_MODE` on implicitly. `KAILASH_LAB_MODE` defaults
  off and no service auto-starts; a build that changes either property is a
  security bug, not a packaging choice.
- **Manifest/packaging compromise** — a tool entry that resolves to
  something other than what its manifest record pins, or a
  menu/category entry that diverges from the manifest that generates it.
- **Supply-chain integrity** — any drift between what the flake lockfile
  pins and what the built environment actually executes.

## Deployment boundary

Deploy and exercise the tooling only against systems you own or are
authorised to test. Australian users: the Cyber Security Act 2024 (Cth) and
Criminal Code Act 1995 (Cth) Div 474 apply; other jurisdictions have their
own equivalents.

## Secret hygiene

- Secret scanning and push protection stay enabled in repo settings.
- `detect-private-key` runs on every change via the pre-commit hook set.
- Environment secrets (sops-nix) are read at runtime — never committed;
  never paste decrypted secrets in issues or PRs.

## How this repository maintains security hygiene

**Supply-chain and dependency integrity**

- Dependency Review — every PR is checked for license and vulnerability
  differences versus its base
  ([.github/workflows/dependency-review.yml](.github/workflows/dependency-review.yml)).
- OpenSSF Scorecard — run on every change; results publish as a badge and
  SARIF code-scanning upload.
- Flake lockfile (`flake.lock` once KA-01 lands) pins the full tool closure;
  menu and module trees are generated from the manifest, so the packaging
  surface is reviewed as data, not hand-kept code.

**Reproducibility controls**

- All commits are GPG/SSH-signed; unsigned commits are not merged.
- pre-commit hooks run the CI set locally before every commit/push.

**Known boundaries, stated plainly**

- The distribution is pre-release: CI gates prove build health and layout
  integrity, not production readiness. Scope exclusions (what Kailash
  deliberately does not ship) are documented in the project paper and PRD.

Open a [general issue](https://github.com/kailash-os/kailash-os/issues/new) for
non-sensitive questions; security reports follow the channels above.

## OpenPGP key

<details>
<summary>OpenPGP public key — fingerprint 9CB1781DC2BB28D37A0155DCAAF8226F3F4C1712 (RSA 4096, no expiry)</summary>

```
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBGPhZA0BEADHNWt/SAwzO9MRmumZSow+WTSGc71jJjoOGjQyzoe/h5Pf4BSp
DyfrnaWYujwkh2l2uArDTqVxMLvsxgsAZ23ZwQ62W+/OnKg8IAFYgd+uskWX/+/B
lBu+kV3SHWayNszzzzBybhwW94MpCEwka5XvunCI1nbE5vkVVBglZfmRIpS0iZeR
cVbc0Hf+xvV+QN6/2b8CMdu5Olx80Bq4mcizsITHrS1zwHsnCp/pWGJrs+68q4as
y7zXkIl34ndwS2nVBQYwDuiHvUi3MqWaXfHhD6nCM+wmH9ZFvJJG6cZUsTo75anz
c2/iX07MEfjwq+gkW3dL0VgrKZ3SINLvstY244roGeOkJPSVs3VpG20yDbVWCHHJ
Kmp8g8pBE7A1o/w6Tj/Ld7rB3Q2Uxsq4TDU+xrhibL+fYcxJHDzauR9+IkiFk8II
3Ab0q2a6DiQXeemTYI9LV/ugSs7jUQ97CFrtEYIY2gCH4SUilgVkNdwuJ1WZJzFt
5/Pg+wmeQZikYhNfj97k1x/CQNhHQDZKWonBWX8ay+tshZW9LILZDTb/MGJyIjzr
WDB0d59lR04p6xSY5a4vQds4J86+60YpPAE7tNy+wgJTmmVV3DXg15eDzMhOvolq
IuxHDgsrnVjGW4p4xov3i9WGUHw/wnr2G1yiiodYWCdla9erIFY0Fmie8wARAQAB
tCNTaGFpbiBTaW5naCA8U2hhaW4uU2luZ2hAb3dhc3Aub3JnPokCTgQTAQgAOBYh
BJyxeB3CuyjTegFV3Kr4Im8/TBcSBQJj4WQNAhsDBQsJCAcCBhUKCQgLAgQWAgMB
Ah4BAheAAAoJEKr4Im8/TBcS/NoQALAHlHOauiQVzCd9G+enB1f2o9f67epbKywN
KXxuev1Hf0MeF+Pp1tlifE+gpTUIrGjgZOYnIsGktSkJyexx/qk5thdtA/GKk1ab
KknZ5s2Wa8qvCVd9RIa14AfBKBQVRbUnpdEBGVNYEPiXznHsbHrTkERSCw6wFx1k
k706WAbXNp0kSnc/+db+fMdBhLQ2AjGYtSyydN4yqiea+HyMCaGQOKG3KPPQR2Ua
9eudc6MCxBUV6Kv5Sq/6DYmMX4IDlrjLhg4Ymurx0oAEcxXC5IIPFKxCG8Mli+w3
ErPXHgbbzdaugHJJudzhnoPav1GOsCYfdqAR5SmCfdHT7SQDQ2sqpG180QFfM1cd
u2jyLyIYmIHZhiLXmGKbls3MjIx/I25FLZ3B8H0wlPc9lupey/q8QfhzmIOSJvK0
k/gfCXaghhwAUNIeYQ2SU0t+k0Mtl2R6PTncJxs6jjW9q2mRWqjLSviJiG4x6MvW
ualyQVglyZyk03DQLE350x7QFUH3x9TKItAHmDgOl/ZfYEob49ysVPK0maKCFknp
iJMC4LoGDbyuN2Lkt+a9gTxIaCFGwLJAvGyXx6yYdNsI7FTRbbRsUhjXOq2TNiOp
ETsWWmJa18ou7RrMhdVvvDynP8IS3O5VKoKoxsP4sW+Byh2upGy19qIDMU68T/R4
Pc+LdTro0dCf0J0BEAABAQAAAAAAAAAAAAAAAP/Y/+AAEEpGSUYAAQEAAEgASAAA
/+EAQEV4aWYAAE1NACoAAAAIAAGHaQAEAAAAAQAAABoAAAAAAAKgAgAEAAAAAQAA
APqgAwAEAAAAAQAAAJYAAAAA/+0AOFBob3Rvc2hvcCAzLjAAOEJJTQQEAAAAAAAA
OEJJTQQlAAAAAAAQ1B2M2Y8AsgTpgAmY7PhCfv/CABEIAJYA+gMBIgACEQEDEQH/
xAAfAAABBQEBAQEBAQAAAAAAAAADAgQBBQAGBwgJCgv/xADDEAABAwMCBAMEBgQH
BgQIBnMBAgADEQQSIQUxEyIQBkFRMhRhcSMHgSCRQhWhUjOxJGIwFsFy0UOSNIII
4VNAJWMXNfCTc6JQRLKD8SZUNmSUdMJg0oSjGHDiJ0U3ZbNVdaSVw4Xy00Z2gONH
Vma0CQoZGigpKjg5OkhJSldYWVpnaGlqd3h5eoaHiImKkJaXmJmaoKWmp6ipqrC1
tre4ubrAxMXGx8jJytDU1dbX2Nna4OTl5ufo6erz9PX29/j5+v/EAB8BAAMBAQEB
AQEBAQEAAAAAAAECAAMEBQYHCAkKC//EAMMRAAICAQMDAwIDBQIFAgQEhwEAAhED
EBIhBCAxQRMFMCIyURRABjMjYUIVcVI0gVAkkaFDsRYHYjVT8NElYMFE4XLxF4Jj
NnAmRVSSJ6LSCAkKGBkaKCkqNzg5OkZHSElKVVZXWFlaZGVmZ2hpanN0dXZ3eHl6
gIOEhYaHiImKkJOUlZaXmJmaoKOkpaanqKmqsLKztLW2t7i5usDCw8TFxsfIycrQ
09TV1tfY2drg4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwAMDAwMDAwUDAwUHRQUFB0n
HR0dHScxJycnJycxOzExMTExMTs7Ozs7Ozs7R0dHR0dHU1NTU1NdXV1dXV1dXV1d
/9sAQwEODw8YFhgoFhYoYUI2QmFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFh
YWFhYWFhYWFhYWFhYWFhYWFhYWFh/9oADAMBAAIRAxEAAAHlNtW21bbVttW21bbV
ttW21bbVttW21bbVttW21bbVttW21bbVttW21bbVttW21bbVs4uQaOz6FaPSJu1h
uVre7bFeMz9g+e2xttq22rbattq2y6Ruwq1ajyksu21baai5e2qOlcQmmxMCioY1
OmfTxT2tPudtzA8nttMttq22rbattqz5jYg9UVm5x1ByfbAYcNnrLTKemFfpoJch
R5JmFH5xhGuY7QzurBdDlboEs3StxO22w22rbattq22rKTNbsOdaq3aE5m6R3XPd
OkGFtnIIgkqiH3HuXmiVT/rGBTn379sZBiWGeuYP+aBqdtrjttW21bbVttW21LfV
16DWA6ezI5vo6xKPaBK0R6hVwlgVraQrQ1dwVr3q4DRtSUbmtGuO2xG21bbVttW2
1bbVnjPC7xvV2WermtLzhDRaNpm/fUWB6hzx2Vu2niNXX11DiHLbZl22rbattq22
rbattq22rbattq22rbattq22rbattq22rbattq22rbattq22rbattq22rbattq22
rbattq22rbattq22rbattq22rbattq22rbattq22rbattq22rbattq22rbattq22
r//aAAgBAQABBQL/AJFJKFLabOQv3IM2TXayp/1UiNchRapSwmjJAda95IkSOWBU
X+p4bUqeiABR1JYSAyQAq8SFG7ifvkbTJHK54uUr+bAqfdICJLJaWQR963tsX7T0
S6V73M2amiBawm0Q/dUO4RlF/N26cpul0o5I45xLEqJXe2tsWdewHZciYxLdLX2g
hyPdXs/zdvKIVIuYpHUpdApqSFiaFUKnawd65FzTiILWpZSkqKI40KXOlDN0xdUc
Kitr9j+dt7gShdUMUWlSM0ptSJQahrOKYtEzSiJKlFR4PmEJkikgYtkVuYraFw26
AHcqxi/nI0okCkqQY7uRLgXEpnRnUR+y1iqV3KIx9JMeSEOGzijCoxG/dIEla1SK
RboSe11Jkv8AnfeCUlOT1SU3asUKCk1xMk0cbl50rggSpOLjjkSrmTsqupEi2jCq
Ad7ifD+ftyFxW1yIjKApS4ApxJVHIVxtKIw1DJMA+j+/Ndf6ggk5chQhT92hqmNC
HeKIQwSGm4lS03tGLyJi4hL5sb5kbVcQparxrlkX/qKG7SlHvUDVeQhyyqlV/wAs
0//aAAgBAxEBPwH9oAdjtCYfQ29gj+epk2Ui+4aEaRjqZIH5u4fQHCCkaFPOsYsj
x3jSJ0rlp2jQmkm/oWEnSy7y73cf9Lf/2gAIAQIRAT8B/aLdzuKJfQ3DsMtRFoIP
cdAdJHURSXb9Ai0hB0CONTJHedJDS+G3cdAED6FFA0p2u12/6W//2gAIAQEABj8C
/wCRSokVepAeqnop6a/6qokP6TU+gfp8nq+HfqD9R/qfKTQPFA7dPapdAKh+b83Q
Gr04H+co9HWPV0P3s5OL04PR9XfAcB2q+rV1SSCz6jX+cS+pNO3xdFfczXxdO1Tx
PaqnROg7ZK4fcPy/nCoirpwr6uhGnr25cj14duav7O9PTt8Xkp0S6ScXR6B66vJX
+g1fL+eofaeY4eY7YLdFeyNe5V2r5+TyL1fQnRgk+16NORJqXgnVZ/U6nq7H46fz
uPBXk6F0V1B9H4dqd9XSPqLyLCfaWrg+oZKfKX7PkXzCaJ9HS3Gg83lxPfAcB/PY
rAU6pSX6PGTV1D14F6nX0eahRIeano+Z+f4v8v63ril5PTvgn2v59UZp9r5EvDyL
EqdRwLGS04j8X01wPq6FQdUgMp9WAfL+Yxj/AB/1AFP4OtH0hinr20fGr1S9ah+0
/aD9oPi+gfi+o/6iCF+T9p6aup/5Zr//xAAzEAEAAwACAgICAgMBAQAAAgsBEQAh
MUFRYXGBkaGxwfDREOHxIDBAUGBwgJCgsMDQ4P/aAAgBAQABPyH/APZJKV8LqfuK
f+Tf/TLqwPqojDz/APpO4VhXdxRhBB8VyCnUvnj/AKH2ee6xP2//AKPH/A9tCJPg
/u8h1eW/Aef9XQ5fLzUSQF+SpouBfVF5BQkkuRv41f8A5kT5N4w/I3YI+O6jBCf/
AIeaIAnoeLL4PLzVCBrwFn5fXX/v/Wkf7n/g44PmhNK/FiQyv+GUf/mRCJhn8V3+
dB/JZcVTw7YY8OE5L+HT0/8A4MJ+p4/9uvic/wCq4Tf8o+v+TXi/+if/ABoPPHul
P+fvP4//ADJYBILyySgO1NIeg3PfdRjz4SxxkeH/ADuxjS4f+RgHw/v/AKSRx+z/
AMi3L4LI2WwYls6JjMdVI1P9VZXLqf5sTlAz2+WnLTPjh/7XDe38f/mLMUUZKNeD
+/izP8x3Vqovqef7vPfkeSlIcf8APShRhe9lwqdZWxLF5ePOxHSF1XJAQ/dE18hz
5UPGnvr/APOEDF+1d02BsJf2vc/myo4fLmqE0zjsT/sSiA8t+2R1U5576vBOEOig
HyC7+L558nEeJ81+VYcusCfn6srr53/v+cL/APmmbxXCZ281RDH2l5mouR9d++6K
eSuH1H34uLN4ObHYEkG8w54KZyYZ4onPto+AL63+FjCk5In+Zp7SnmnAB8f9Eq6/
X/58FBGZE4/HussByEfkq8jGG+xrT9IgX4piAWI+HJ3dfxKlQ+8L68RYRI4Pz/8A
jUCWgTq/4yqrL/8AnzZxw/FNhBWx5+aWJ8Gfz+bMqF/p/wAVlp8X+0K2PxNVwp0w
+ZovH5r/APYL5T8bev767WPHX/6EaL0k8UTw+RoO1+j/AHeNYcHj/wDdr//aAAwD
AQACEQMRAAAQ8888888888888888888888881hQz3888888w884xJa0ds88888qz
Y/CTn4wJr88888sGVWrLwLtud888888d5JTQGHR2l888888/t1sduNt988888888
88888888888888888888888888888888888888888888/8QAMxEBAQEAAwABAgUF
AQEAAQEJAQARITEQQVFhIHHwkYGhsdHB4fEwQFBgcICQoLDA0OD/2gAIAQMRAT8Q
/wDyFeoHzfYvoSJw/jUfg+f0+4Qsg5/F25hPi3kzhvkfFA1keCE58A6b+NPKFhYk
DrN5fEOdRrYcth+NvomXcZ34vmZD35AHUHadfjHOYSPMPAvmI39JaXe//wBV/9oA
CAECEQE/EP8A8hBL+PD6sO9fjE/B8R7xayMA8fi6cSPzZw7yXwngK8QHLI8FqzHP
xhwlCUmCmEDh82b3dW3BHX8fTfBzSD630oR14Kvcj1YH403iQn3XxL8SbMAs/wD1
X//aAAgBAQABPxD/APZKYk9OPl6oRKetX6z90povo/2047P8eGgRi+/4YfxWRoMR
x/8A0mTKPLwHyuWaT6y+3M8uFJkHgiD7jfoKKIE4Ty/By/VnRF8iH7h/X/YSXgcH
3/u98rh69Ph//R9lchw/0H7/AJpQROMgnuHB5XWx1OUnf+g6P/tcMDy7+Hfzx81F
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
kis=
=/w8R
-----END PGP PUBLIC KEY BLOCK-----
```
</details>
