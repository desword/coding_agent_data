#!/usr/bin/env python3
"""Standalone Android/Codex experiment. Run by double-click or python3."""
from __future__ import annotations
import base64, collections, contextlib, csv, datetime as dt, hashlib, html, json, math, os, pathlib, re, shutil, signal, socket, statistics, subprocess, sys, tarfile, tempfile, threading, time, urllib.parse, urllib.request, webbrowser, xml.etree.ElementTree as ET, zipfile, zlib

APP_URL = 'https://github.com/android/nowinandroid.git'
APP_REV = 'a49ed253d75e61a2b6ab80a8da677b57437b08eb'
FLOW_URL = 'https://github.com/ChrisThoma/android-bug-priority-tree.git'
FLOW_REV = '3c473b9c3e7620df2fc4ee830921e8512036416a'
APP_ID = 'com.google.samples.apps.nowinandroid.demo.debug'
RUNNER = 'eNrFPGt328aV3/UrsO7xAdiAsOT0kaWKnnVsp/Gpk/jETrutyuWBSEhCRAIoAFJSVO2Rk8iWbclSEr9iybG18esktuQ0ie1IfvyXViCpT/kLe+/cGbxIKo92t/YRCczjzp07d+5r7vAn/7av7nv7hi17n2k3JHcqGHPsF/v27NnzZt2Wqk7ZqEoHnYo5KRl2RSo7tm96DSOwGmZ1SjInA88oB5IzzEqHqya0qFaNYceDJo4teWbZ8Sq+BuD6RjynJpVKI/Wg7pmlkmTVXMcLAKztBKy13yeKvFHX8HxTZdDMMquEF7+hShUjMAOrZkqGL1UCVXrbd2xVcqDaNYKxqjWswqCq5I/VA6sK39aobeB3fdj1nLLpQ0N/Cj6CMc80KpY9Co8AjrALplwoEZgdsKf6+l49/OZhSRfAtWPwrcAkrCpMIad5pu9UG6aS0wBh0w763njrROmVI4ePHjoOnYbk5uWHO5e/klU5XPpgZ/Zk89I38Nw8f6t54SE9b2+e2956iIUP55snN8JTc+E6lr914pWXwvuX22ffhZfW2YfN2ZPY6Nqt5uZy89Jp6tNeWwiXHuHDxlfNK+flYt/BN44ePfAyDD0t+64xYZeMUcAKWvimXSnVYPpQIF4t261j3QgQ2Zmou6XA8MfhfcKwgqgjvsBXuer4ZlRo2YHpeXU3bla1fP7iyzN9xw+/fugfQmKmr69ijrDFLTnDbyuNAq5GTsr/Gr8LfRL8s0Yky7dsPzDssqkAa/iBl6Mq/Bd4UwVgBWA2m8HRqo5R8ZVGLmphTpZNN5CU3xnVunnY8xxPlU5MufSYizo3WIfohSFWtWzTV5Ap+Ig4WgR4wgrGGMdojmvaimmXHeQ0Xa4HI/mX5Bzy7kjcHP+NOJ4EfIxwJcuWTLteM2EPmcqIKg3k0m07xkv+a+iJySK4XNdmHcSrWOUA5jxlmdUKYNLo6NWNWm/ZFkwtIhhIh8Cy62Zfsv0bx7s3JoISOWtmYCSpidQowa4efhuJ0UFsPgGo1kbNQJFh25pyTteBo3wfZEUJ4clp+rh61Nw1ppA8sA4wzPTMoOR7Zd2lOt+pe2VTVPVlSAaSKkk26KdyuiGITHsQOToUc7j1YdoF8aBYXR/OrASUEEjJrPpmFgW2nbAXnzeTYSVWmgBMjfAzCxzLdgHPeXxatipyAXaTwolicVrJck6VZJJ01IBBFFTF4hLHSXRxd6skeLZRMzugMWKVcM3TQ8N7AT9nkpvydcc2iZG4vihxRvCVMacG2sCpBxULWNBznABGR1FheAHnporpBzq12Cc4yJcHWblWG4dixZxE8eaM6ye8Ot9QnBs4xEhYDBUBTRLqza9Pbj++3/zrWnP1DGvHdY505NC3Txaaq5+FNxfD+YfbT662N66RTP/77Lsygz5s+KaOuKcwGnHqdkWwGUcAW2oMP1/JpdAYkWGM5pln4fwDGqO1sh4+vfjtk6vT2GlGjraai7uMAfJGq86wIv9UQyFSlTPiNLsdXA3oGIDyA+LUmFL+FVE2/2J/f0YciH81nTZ7LgusxgyM2hByW7FAcx3ir0W9lpXaXKwUQM76Pqv0TVx6EwjEF2UGwfJnnCEDSYzvA48RBhNjoMolXNdCYggXcAFIAqT0F2naYqSy1FoESrMCswZUZ9gPiX1RxHrRcSYpryKwEdyCNAwcMR41iqYgmnIu9+vVQB8qRgtmsTHARjEriuiTWKuaTtSzioMSLAdsKB2ZeZ/imRoID8WTh/7LyL9zIP/H/vy/l/JFUL8lWbVyL8hi3WOMmB2llR13ar/CJgk7sKgS1NwgDIXiRKnho6jVqXaQI64ZLmjBCrRJ7lmqUyVFDh/9tbnAd8iRQ1L44UJr/mF4f5m9zH3ZPnmB2Bc3R+8VjZmdILWuvk/d2usPGNevYIOFM2SRtRZWm1+fC59+GH7xCcLNcfHhN3xjBPQhJ6avo1hqcAGURH+PvOcFH7HxtSq0sVy2C4D1fVT+iiLrQNQX4C8Pf/8h57jA9Wkc36i5YEByixSVGwolpB6KJsflw4PVfJy1pCnx5myfwHqWgagG2FuDTA4Ykmt6eSY2JSMAjIbraDYzy7uLTSJPyGrWLlFtcwJ1rS53mCgTOpBGm/CA4z1lBBZ7gr84E8qQjFsfJl9zS/WgDPOF2eAnfZXdeglQK5MJ6Pl+adwaxnKnVoOZyMWY2Wgv4myQCJrll9g+TcudrpYP3yKxla95dRswc31cAmPSIax01WWfewEpXQVcdBXR0IGjy4bL/BJQBGCQMkGvBuDf8CeYIdToP++0pqJFzOp/sVmrNrIq3wt+UAE4mu9WrYDsmlx3O85FXtKrthZxF3ZRUNWpP+tp01VhaVlPsIZ+zhiFvQ31F4GaFWsUIOQSxQOJ4kI8kyGw7xXRMVfU2WPHkLG8BZp2Tr2bYE0pAsczUwLWJV2kNpBcES5JIYtoNQDpXHcRm6FFhJ+OQ2VFbdeZYMOOFrYzoVcCTTieGrwr8I7P78BqaMDzOSCjA9jXDKFWskzg7i6xs4o1RYJCarfB8OpP46Vyi8UuI2oj1bo/lsEla5Endsvx6FGY55FajYiEWxK9QWU/l5bo/KK1XEIrIGWgj3pO3fX1hPeuQQcDNgDTFlWjNlwxCkP9ar8Gf3wCP8SF2kVUCYp7SEOUWodgyDfB7mKSq5PkozphO+RlBVkR1Oco7IAX9AF8GICHEXAcAgVaJqVaMYfV+6EaGRQqhZDjE8vS/bfmFD3ErlRsuaWtO0ItWxnZ6VyPMLTlAm5+6pBT5ZoxWWqA7T+c1DNyAYphC/UXGYnYTqMeWgNxgX3GuybmV/LrNbngoapVqPvAbt0HOAROBOpN/fbv0o97/CzuE5vv4kHlSp+vH2wEH+whsNEtY9R2/MAq+8I+QncCZLEwJNFoYR5GEbW4Iu9DSDI32bCFrguDgmloXgoKG1GtkaQhJGYi+ytVHLOUM2Gbns4QYF4Mh6UKmINS2ahWUVEMStwJjdCOgwAprzcyqnLf7c4OZk3qjIP8b7oMW9bFEF4JpaqMFMm4tK5waLsa7+MW+B9uEuYgo7eecBYZsYXPxrWWrMm5ofxAMYsgwsO5KvJI3WaCooQUQuugDvKmVgocp0pFpLYQOHagOFfnZgbD09ejqBHHCArrNRaZSrqkFHjiXnOnCO309hG2oA4bp4u+R1TBwEiQA0uy3nDC/+02LgEpELMM0VtRV3DuKkOC8QhfBSGxgGZgZXadBqcZBuW6axxca6CPjsAJrAjSMTTjYhAkNTfIlqKZJCbUFT73QRI9WEEWDvn8gjjJ1v54KWaruMIzy5ZrRVGVHqOnYyB8rioGC0VIGwu6U0YIG+HDTIuIbqHHCiQjvQUmD5LxXhbl4L4Twxh8ktb1W3EcuMAWOR0MLgiUk0FhJux5hca0o6mI8GIuihgX5PaD91oX7gofaAEwaz97Fj6ba954HG58kw0pFyJxoxEiPMJcsKMYc0EGJyp8dCucexQuvdu8+KC5tBwuXSKMm/c/BUjga1EDGnz78WLr/pntzfOttfX2+k1CAZ2ume5mLIrh3quRkPhiUUb2TKfxnilM2zPSNHuUgMTt9562N7YQyyvnAT9OXYb9noyJVO0tlbhr0EU4iZou1kV5F2nQa/uTb8t2fyHSE2KyCtv8KpcNIBgSmz7SH6qCuJGwYEOiMlHBK2B2JYfYEc7BPiT0cO7fdQrQS0cwzTQUaSVQ0p4xIZSGINQgj1MzMQ31aUL8RHrDrk4B+Do6s9x1IpPQsDGMUrXKVgD1aP2g94AGaJ0cY3SX7FGxq7W+3YLeJMw7HRsGDYyIBo/dsndas1SR6XcNFHcOJZr3GlEsHp6IgMRgGDCZLToKL6j3vhh2KlM668c5TRBHznVBxkxGgVn4tBfcdF8cJRad+NYbo39MdsZWFIsMM8Lk1MRzLiVYuagVYhSDSu3nF8KVT1pbHzU/Wc0esBXYRDoEKpbuJk1BjoHsJJDbj++HSxvtOyd/lBDd3gIw19vra/AKcjHByyigVu+BDN1+fD68v8xDt1ff3zm9GN5c3Jm9CgoDRGp4arH11UZ49kZCkjJqo5OpjJtTOnlZkldgFPSiw8gikRELkmhDMXdfOL4gWdIRO4CuJsRv0mCvAkvZZcuMLfY4hHXMsDySLUxoMc4hOeCzPQ1sDgwozGlVss2GCVq+7Dm+HxnZURyLm/598ZZhDbob5MLcTkvIem0YN1nKzuZ9f4C1/S8xtss/3rj8F9rpZGeBSdvVXiY1xu3bXqKBFu2fqqwFVrGy7TxlRS3Kwrpmhb6ZJtVZc811XAX6dypxk0X5e0wFnNY6ZUfosjzIJbwuO+Py9z/kNVIBKUxdiONPHF3NM92qAUwm/xEj0f39hf7+bg4C0x27gGNz+SHAYE0MLXjHskcc4HWmXJDJhjNlBTALLFA+cQyECIUhNQnGh10yKud6hOtgv4DnrAznjZwWOIFRLfEyJdc7GsgaSL+S+rsNbZujLKklWpweY0drR/EQDvWnA/39/eqLue9zaB5lGKgHeJg+CgEJXrDshgE+XylmnL7dFas492bntkKSsdCDjCwsFxgjR+KiAFyrypxRWKirIJhcZutNZexRlcWUSzVfLogXFVxEw697Zo1FiMhCKtC3yk/RWZZMAqGUUozMUj42majcQOQVtOln0gYu4q702Ji5aC93N5j+P6gmyxmSYUE3Ysmcy2NR9U8imxzZA7Hi5udbngm7vFRxypMKnTbVDNsaASZTSb0n3SuRi4GJUdhDpEUdcsosnJKu1fwxwwPzhTc6BhCP2OUxsHmlN3/z8kGn6niZDs5krarZvujxZztTjzkwGsYWRIvfHyq9/ObhA7+lU3td4KGASIV9qFc0nwebh/qLrAhkg1uqgRdk2Toho2i/pNbasBOgWuiopXO/YKpqIkD89ofk11EWVtGXYSXaCOhrtiC6/JqFhoozEkh/MF41LTnVxLfeMfVjgTLQr/08J2pKZpUxguYd8zTvFWgHRhvoiT/jqVwBGCU44FsGmsNZ2LnY6kFIJaFlFfmEFVQxpepVymmTBhLP+5N+qR/PKoaB8/qOOVF1GZdR80aHdbGmSr8K/3Fu8bxA6ZUcr2RUKiWYopJLFbD54nHWD5hxgLMrZReF5lyMxo2IM+x44CAgYRIdtUlkeLBw9k0U3GMefr5c8ZKkoW6ILJ3kK5jeV3Ma6PVgDeFS0XAaY0RbRabUyPDm1ebHm+33nm4//Qgs9O3na+H6JzufLTTP3go/OCsDgRJ9Abox6hkuIEOt2s+XweT+9slV+QWxHXl8q86Ek8rOtpeWt5+tCKWbwWL78axEsMA3aa9vguuwc/r0zsopkTlYBZu6qg9QZ56Q5+vp0YQ4ZG63zBaVPeroGaF0wFVGhvbrNQVdhcmhpANVpIj5JDvsxNZdpzwi05E+ntNPC0RmpO3HnyXzYPC0noWVWDOGxYzUvLaGDtfGqXD+c/CHwsWl7aer6bjTQjj3hTSNSBbUGQmQy78kEXrgJbU3bnHPbWuufftUa+US+FmtM/Pw2b7zafOT5fDjuwQdRoUBoqBZuL7QvPhVc/ZO+ODqzurs9uZm+OgWBdAod6D72t5flg6w43g+s4sPth9vSvILaIPjeUi/KuafH8jlXpDR5YtbLm5vfdpeu9s6d6/1+bn285XW3XPN+UvguwKW0CAeOEpEmvALnVjA5Jr31igJKSJpREaiHqPNo+ans83rtyjTgONxZSNcvr39/Fp4/8rfwS1nr8hmH8/xyN7mqWiW0CA8fz28cw7o3Vz/mjdeuhIuXGK+7CLsjubievP+zXD+ZvPS/dbqdQBFCOycXgLS7Kw83IWcSX7uslUE8wIpzN4bJgGPNu7O7Gx4ejMBlRYnCdmctIISRgQyYNmCtR/OgVfdoyeabxXU7rL6ilH1zVwvXEgAACBaZ5hq88aj9p2T9Nr++n3w0rWy34ABqQ44r/3FGtCYp2ZTw3DpLEUkYFGoBJiXKI+ZLis3gMjNDSD1Z7RkGA8mcLNPtr+5jkGFhblw+XN8YHBwlxHDzV9qP19tfb7RvLsWfnKuuboYnl3bZbF41Hn2MswJEZcwZrwMuMwSZ4Wn5hB2IkiMyT47c4swMYpSNOe/xDAyoLG+1lq/jNuRtQPW70FtCkFMARoW2CHM1fNRisFCIYMzXGB+zXP3aNzmmTsY6PhwgYI6RCq+6Z5+0NpahUkTe24/udF+9lG4BctzHZBqPdkMb36BtZdvNC/OR/gipdfXsozsZcWsODVPxw4xrynhgHaIzT20UtK0B5ovdexbBMl4b43lN82CHgIyIyPdeTfcuM6kJ3bofhhcZHJXcMoKPUgHj721V2rObgFlwi8fAGvEILKHwsWZvUC2N48fT7Vvbd6OuyRPgYv7Bvr3/6ygDYzMSK9ZLwONsGtr5XF49gau9HtPKcZFSw6ifHvzc4zXofR5lwfq2eHA7mIOQAGjIMcktg+RL8uysQLdXJBosVtfbAGHU2wuozdhDt8rp6EY22kglYU+LLD+Q/A4JMKUxaLILuhWhfkGrCipZAWzYIdEciZevdBpTuyZ6Wt9QAVsff3F3CC1INNJl49ao2OBdHyM7MMDZVxQMBnTbpZZrapkfdvSO5arEASEi9lEWO2rQ4n7C9fWYG/iA9PFKeWL8TQGkJnzOn6kxhpXFVsdziVTZGB6woXLdeZ29ECOGZjOBBhuHD2UEuMU7rRz6og8PQx2QS9serEWY6rWvdvh8nz49KPwzCLp0fad98P5jyM7oTdrPT7DWQtDvVunmh9cgeYZ1voOJX75RgyeslC99C0BtiyFF/uLavKyQKcUmbZmNNicQ4lIO0iBv536kBXG8XQolP4isULBkHFJkh9n+BLvUTlvJbyO2OkwRkBaIbHjBNQ/Tfb35+HjJfgbhr8y/JlQMDBSlFUJfGYJEUrG7BN5TuywIzu7aJShwi/6YV8p8t9mb3/7ZJ7MNwICSk06ePx33z45I4t0uahb7tfQjSeTJoNb7FAgGqZEcTFt3DTdEoavS7bIEtyF7hRpx9TrjrD7jNS6d4/RVcTdZyTmDqxgGTfgizOxCOR4Mxv71y/2F7rY2OR3hF9cbN3cBIaVXuxH61nYx1HvGSpd4QYuY0+gUJJbUXv3ZO1wZUUKlz4Nn70PDoc4UU7xdQcrb29tgemw/RiMlQ/QKGBGPClk2Ep0Pps8V0bVnTjCRhX9/Fp742Rzfjk8e53OklH3gSr+8iKZ8cDCQFiw0kEPNq88AxLQKfsu9gr5BXRgFC59RtKf7AJupID+P72J6fzsuKZ54zTiA2SbX0a02ZENwI/Pa7bmYdnAJqbzGtSNc/fCJ7OJmwFgY90AxYdHQGjTrIRzgPal5o0n4ZMl0obNJ0tQu6uLgVuPHIukIwQocfnbenKpdePkzsXn4eZtsnD4UTyzcKL+zANgB+T8GsJJMvTQLfgCfKeTra07zTPPtx+fhZXDFYL5LAJy6zClnQuz4bXTeJ2BGY+7oEuTh7Xcmb0QJRGQvg3nr4XzpxgVHoEPzVXxyjqee63Otm+fJKdr58oc4JnyfRIBq96CT44yHoRTx01I3ArJkBcYi7gnYARgm+1n51hDNPRl7W3HSrUFcVuMDHrfaJiUAEmBNsM2qlPvmAq/eBJF2TKnY9GRmt4r7y1jO2KmWnyJJk754cav3vM0Ls4BV8RVl6yRLud6pobnfWt0t5zLEbw15utDyZAqD6LG8dN07DQZM00HTLtGS9PB0WQcNB38LGZS1jH58/c8bV1laFJ+IGEcJ7KPUYJoOtTMrTdO3FQa7vR4QYlvC3RkFrAjcqZKGjlu4jS4ISjMGh6jFQs81N2BKbJoCyiCLjQp6uzYKM525RCygGOPo6hncnYjXsh4mnI3hsnqhX+AYXZfnPgS7fdbIDKb/i9WJ5p7JEC0AJPdaChmNijyn+yEdOB5XZdvJGJKZ5uX7lOQZXtrsXn2aRM0AouVJG+ooFTruJLRuZRlZ9S23jGje7S4qIkAXdemaMGUhqcCU/BTJnKXCdwloSQEHh+ITTJDHBZ63H6+BuzBbhClCcQupFbqNdePXHaYKHJzyfDLlqWz6IhqgTywA31/rgcVkocX6ZF5JgUzejSsl2OJG4nYHkciNQMWjotjw9XF1XPtAE8aPYZvnoL3bTzLpWNbCrqAyg9XH4DLzcN8ycAvRmq2rrTXb4I1gZp1/hTwQqy3DJcpKJGYqsj5PLjlb4NfKavcqdRlTVbHzKqry6AHweCQfmPBGGvfoFbkF/nEGMwrocJdB8DczQg+qj+83L6PZ3X6+/yaM24Sf/ORyVoDSwy0YXtjkewcbrj2HKjGYmXlMccCkaMjIxoVx65OYRoZMoVcjOcY19GARC4MdM6dbK8/BpWP5uHC5vbz9eaFb3qPye/nyComSmAafjTEwEv9/Rw4BUh4Ds+dD8nsIhJK2Gz3KVVjHDd2Zs/wyBvZSeHyIgU5mwunw/WroFC3nz7HIMT5B+A77swttp6u94Yuzv8ElhjKIIMzs9DSf+/DQOQkXfPKm5Ou6Vkss1lidtmDcGuz9zDcJhHj7JxexB6MM5uX/wfwpDCkGHOBkox4eI7NVsDG5GcYgIwNfFMic4wl5/KREonx9UBP/YJCsllOo9uOddxniZ9UiMVQ8ko7bv3uEodZRUzgdMiPhCvKDSJ9qBbfyyGY0UXbnJa5BYsTU2oFcXM1FxsZCTuvi5E3KLkeHpRgNhqRu3XhOrgMJKnQtlShY25Q3IVP0pBz9K8GCriWJmUpRIwuhc/ndta2wpt3wJjfWRG7kQuRLrTmNb1pTUKge0+o6NUxGb3gY+C9Pbw0nUtinhRcyFj3r4Srd+VsdxgIe6ONl+6eFEHo3HWHwC+rToxZ5THMgGQsmwIT3RFllRj03HgUzs2H62fan86F3zxsfbwFCPK9ffDokRh+x9XCUZYRmz8os/CSoK8KIq2RZzsDa/OWnwfDw6qY+QnHG88Hnonyj24BJq8rHjr8u9ffOnoUawDXLjVIc2QSRDw5JVIOEWHxTAAVRSQ5RRiaHSV23GPDS6veCL4q8t4/7K3treT3vrr3tb3H83tHeM/ue5dkVi+uiLiYmpGtlQSi4d12JbdP7iHP5H2EsMCA38Ong1mf7mRGl/LpcKWPMocPOYwV8MKyZNTBfIVNbtoNy3NshCw1DM/CYKGPtwkdKR6T5yRqYiMBL1LMivPlLuJlkEsQLvSvvk96s9NUTIDtYeSgmav/KF579fCBQ991jzUX3T+lS6VsyIbpdY5Imwc5GKpRmv0o0OVaRY9hmZNmmYFkAhsfTBuXAj0+UNVWlG2ez/vAVMMOdkKy55mJEDEVamM9YTvwmB1uMN81yrDVmJnRSbBiSsIypV5AHIGLA0wJGopVfdyiGE1FZA7J+UjcMulOqw0yPlzeCM/eBdXJg1Xs5BSkjZD0KruVmfgRCQ6AK96tj5rXruNR2zMUUXS0GC6fT+uMFZJNGHfeuI3xuuen8ejv1MfhHHcq4p+S6BiPOeA62/1sz6OOdWC7OLZVLiUqo0JsER1j0kZLO4ZiB5sN3JhCYfa+Y84cQeIUNQWABB8o+dHv0x2a7vLTFMjKSZY+xuDBCkaClxAQwpZ94Ztlp7odOXaYJ5eBJyuCM1m+77gkq0c/LaUdbrA8knQTdnjnJVqdYE/8XpCe/W0Axoo68nBZw58JYDTr8NdV9rMBasUwaxxFzNagoeiHCTJodM0tZYPgjfg6rD2eK7BLcnpSbImb8EkjhWWKwJ5k3WM11e3ycYK8J6jz4UkX4x1dkm8jvsPp8CEG9v+sa5qs5PjauFWtuqMxpei3v7TjR35z4vCbr/VMzjxG+Bx1nPG6m/1RkY5xGHR2DXqX3wT44ZP9fvP47REwBLpfmvqBc4lWm00lDXPEguGqUwW68s1+giHmJRboEFP/Ra7Hz7LgNjULYsl+Ocj3LOlCdh/BzIkDXcP1YZ1FUi/l1WalUD4jpkSuLaBq+WNm5Ydf0MdQqi7LiZ+bSt0H6CnavuMXqGhXazzSKRdoHJxw3LbjR5AGE79NwMYsoXmUtrqAL7gZQ1AOvnHo8H+WXn3jtcM8+7+bdaVxGzhlpvUl/SAVE2b0jp9NirFgegsnQZIwHZDSp0WOWoG+VVnEMQppSwUsGHZuJBfwUyXSloRtUWjg5R2mbksOPHtgMMuFWAdTXaIkk4ebTV+PEqcpG17djRtUWTARwRJvYK+kWVMuZArURG5QocywilN+CtGjmg3bFxg5M/l27P5R5Dmq6YSmAn7OxPdfdnc7E6ZFdBT46K9kRuARJPSa2dcrcpbpnQj5Rl2zcWDmRmE6WfZoMXVQQ46LAJxKv7pxEpP8KuYMmk4bj5rXb7VWz0lZuwB/GSiZVkkWDriKuj/la9QuFeRjOghGLrEk11IJtmephPG+Ugk2JnbC9VMoApjr+19t2qOF'

class SetupError(Exception): pass

def command(argv, *, cwd=None, env=None, logfile=None, timeout=None, stdin=None, interactive=False):
    print('\n$', ' '.join(str(x) for x in argv), flush=True)
    offset=0
    if interactive:
        p = subprocess.run(argv, cwd=cwd, env=env, timeout=timeout, input=stdin, text=True)
    else:
        with open(logfile, 'a', encoding='utf-8') as log:
            log.write('\n$ ' + ' '.join(map(str, argv)) + '\n'); log.flush()
            offset=os.fstat(log.fileno()).st_size
            p = subprocess.run(argv, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout, input=stdin, text=True)
    if p.returncode:
        detail=''
        if logfile:
            try:
                with open(logfile,'rb') as log:
                    log.seek(offset); output=log.read().decode('utf-8',errors='replace')
                lines=[x.strip() for x in output.replace('\r','\n').splitlines() if x.strip()]
                detail='；错误输出：'+' | '.join(lines[-12:])[-2000:] if lines else ''
            except OSError: pass
        raise SetupError(f'{argv[0]} 返回 {p.returncode}'+detail+(f'；完整日志：{logfile}' if logfile else ''))
    return p

def host():
    system={'darwin':'mac','linux':'linux'}.get(sys.platform)
    machine=os.uname().machine.lower()
    arch={'arm64':'aarch64','aarch64':'aarch64','x86_64':'x64','amd64':'x64'}.get(machine)
    if not system or not arch: raise SetupError('自动安装支持 macOS 和 Linux 的 Intel / ARM64；当前系统或处理器不受支持。')
    return system,arch

def fetch_bytes(url):
    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'android-agent-experiment/1.0'}),timeout=60) as r:
        return r.read()

def download(url, dest, checksum, algorithm='sha256'):
    if not re.fullmatch(r'[0-9a-fA-F]{%d}' % (40 if algorithm=='sha1' else 64),checksum): raise SetupError('下载校验值格式不正确。')
    print('下载：',url,flush=True)
    digest=hashlib.new(algorithm)
    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'android-agent-experiment/1.0'}),timeout=120) as r, dest.open('wb') as out:
        while True:
            block=r.read(1024*1024)
            if not block: break
            digest.update(block); out.write(block)
    if digest.hexdigest().lower()!=checksum.lower():
        dest.unlink(missing_ok=True); raise SetupError('下载文件校验失败；已丢弃文件，请检查网络后重试。')

def safe_tar(archive,dest):
    root=dest.resolve()
    with tarfile.open(archive,'r:gz') as tf:
        for member in tf:
            target=(root/member.name).resolve()
            if not target.is_relative_to(root): raise SetupError('压缩包包含越界路径。')
            if member.issym() or member.islnk():
                base=target.parent if member.issym() else root
                if not (base/member.linkname).resolve().is_relative_to(root): raise SetupError('压缩包包含越界链接。')
            if member.isdev() or member.isfifo(): raise SetupError('压缩包包含不支持的设备文件。')
            tf.extract(member,root)

def safe_zip(archive,dest):
    root=dest.resolve()
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            target=(root/item.filename).resolve()
            if not target.is_relative_to(root): raise SetupError('压缩包包含越界路径。')
            # Android command-line tools archives contain no links; do not extract one.
            mode=item.external_attr >> 16
            if (mode & 0o170000)==0o120000: raise SetupError('压缩包包含不支持的链接。')
            z.extract(item,root)
            if mode and target.is_file(): target.chmod(mode & 0o777)

def java_valid(java):
    if not java: return False
    try:
        p=subprocess.run([str(java),'-version'],capture_output=True,text=True,timeout=15)
        m=re.search(r'version "(\d+)',p.stderr+p.stdout)
        return p.returncode==0 and bool(m) and 21<=int(m.group(1))<=25
    except (OSError,subprocess.SubprocessError): return False

def java21(env,cache):
    candidates=[]
    if env.get('JAVA_HOME'): candidates.append(pathlib.Path(env['JAVA_HOME'])/'bin/java')
    if sys.platform=='darwin' and pathlib.Path('/usr/libexec/java_home').exists():
        p=subprocess.run(['/usr/libexec/java_home','-v','21'],capture_output=True,text=True)
        if p.returncode==0 and p.stdout.strip(): candidates.append(pathlib.Path(p.stdout.strip())/'bin/java')
    found=shutil.which('java',path=env.get('PATH'))
    if found: candidates.append(pathlib.Path(found))
    cached=cache/'jdk21'; candidates.append(cached/'bin/java')
    for java in candidates:
        if java_valid(java):
            # Resolve Linux alternatives; macOS /usr/bin/java is a system launcher.
            if sys.platform=='darwin' and str(java)=='/usr/bin/java': env.pop('JAVA_HOME',None)
            else: env['JAVA_HOME']=str(java.resolve().parent.parent)
            env['PATH']=str(java.parent)+os.pathsep+env.get('PATH',''); return env
    system,arch=host(); filename=f'OpenJDK21U-jdk_{arch}_{system}_hotspot_21.0.8_9.tar.gz'
    base='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.8%2B9/'
    print('未发现兼容 JDK，自动下载 Eclipse Temurin JDK 21（约 200 MB）。',flush=True)
    sha=fetch_bytes(base+filename+'.sha256.txt').decode('ascii').split()[0]
    with tempfile.TemporaryDirectory(prefix='jdk-',dir=cache) as tmp:
        tmp=pathlib.Path(tmp); archive=tmp/'jdk.tar.gz'; unpack=tmp/'unpack'; unpack.mkdir()
        download(base+filename,archive,sha); safe_tar(archive,unpack)
        matches=list(unpack.glob('*/bin/java'))+list(unpack.glob('*/Contents/Home/bin/java'))
        if len(matches)!=1 or not java_valid(matches[0]): raise SetupError('下载的 JDK 无法运行或版本不兼容。')
        source=matches[0].parent.parent
        if cached.exists(): shutil.rmtree(cached)
        shutil.move(str(source),str(cached))
    env['JAVA_HOME']=str(cached); env['PATH']=str(cached/'bin')+os.pathsep+env.get('PATH',''); return env

def node22(env,cache):
    node=shutil.which('node',path=env.get('PATH')); npm=shutil.which('npm',path=env.get('PATH'))
    if node and npm:
        p=subprocess.run([node,'--version'],capture_output=True,text=True)
        m=re.match(r'v(\d+)',p.stdout.strip())
        if p.returncode==0 and m and int(m.group(1))>=20: return env
    cached=cache/'node22'; node=cached/'bin/node'; npm=cached/'bin/npm'
    if not node.is_file() or not npm.is_file():
        system,arch=host(); name=f'node-v22.18.0-{"darwin" if system=="mac" else "linux"}-{"arm64" if arch=="aarch64" else "x64"}.tar.gz'
        base='https://nodejs.org/dist/v22.18.0/'
        print('未发现兼容 Node.js，自动下载 Node.js 22。',flush=True)
        sums=fetch_bytes(base+'SHASUMS256.txt').decode('ascii')
        hashes=[x.split()[0] for x in sums.splitlines() if len(x.split())==2 and x.split()[1]==name]
        if len(hashes)!=1: raise SetupError('未找到 Node.js 下载包的官方校验值。')
        with tempfile.TemporaryDirectory(prefix='node-',dir=cache) as tmp:
            tmp=pathlib.Path(tmp); archive=tmp/'node.tar.gz'; unpack=tmp/'unpack'; unpack.mkdir()
            download(base+name,archive,hashes[0]); safe_tar(archive,unpack)
            roots=list(unpack.iterdir())
            if len(roots)!=1 or not (roots[0]/'bin/node').is_file() or not (roots[0]/'bin/npm').is_file(): raise SetupError('Node.js 下载包结构异常。')
            if cached.exists(): shutil.rmtree(cached)
            shutil.move(str(roots[0]),str(cached))
    env['PATH']=str(cached/'bin')+os.pathsep+env.get('PATH',''); return env

def locate_sdk(cache):
    candidates=[os.environ.get('ANDROID_SDK_ROOT'),os.environ.get('ANDROID_HOME'),str(pathlib.Path.home()/'Library/Android/sdk'),str(pathlib.Path.home()/'Android/Sdk')]
    for x in candidates:
        if x and pathlib.Path(x).is_dir() and os.access(x,os.W_OK): return pathlib.Path(x).expanduser().resolve()
    sdk=cache/'AndroidSdk'; sdk.mkdir(parents=True,exist_ok=True); return sdk

def prepare_sdk_manager(sdk,cache):
    # avdmanager infers the SDK root from its own real path, even if ANDROID_HOME is set.
    # A manager stored in a separate cache can see the wrong package repository.
    commands=sdk/'cmdline-tools'
    def usable(directory):
        manager=directory/'bin/sdkmanager'; avd=directory/'bin/avdmanager'
        return manager.is_file() and avd.is_file() and os.access(manager,os.X_OK) and os.access(avd,os.X_OK)
    candidates=[commands/'latest']+sorted(commands.glob('codex-experiment-*'))
    for candidate in candidates:
        if usable(candidate) and (candidate/'bin/avdmanager').resolve().parents[3]==sdk.resolve():
            return str(candidate/'bin/sdkmanager'),str(candidate/'bin/avdmanager')
    commands.mkdir(parents=True,exist_ok=True)
    cached=cache/'android-cmdline-tools/latest'
    with tempfile.TemporaryDirectory(prefix='.codex-install-',dir=commands) as stage_dir:
        stage=pathlib.Path(stage_dir); source=stage/'tools'
        if usable(cached):
            print('修复 Android 工具目录：复用已下载的缓存，放入当前 SDK。',flush=True)
            shutil.copytree(cached,source,symlinks=True)
        else:
            print('未发现 Android 命令行工具，自动从 Google 下载。',flush=True)
            repo='https://dl.google.com/android/repository/'
            document=ET.fromstring(fetch_bytes(repo+'repository2-1.xml'))
            package=next((x for x in document if x.get('path')=='cmdline-tools;latest'),None)
            if package is None: raise SetupError('Google SDK 列表中未找到命令行工具。')
            host_os='macosx' if host()[0]=='mac' else 'linux'
            for archive in package.findall('./archives/archive'):
                if archive.findtext('host-os')==host_os:
                    name=archive.findtext('./complete/url'); checksum=archive.findtext('./complete/checksum'); break
            else: raise SetupError('Google SDK 列表中没有当前系统对应的命令行工具。')
            if not name or '/' in name or not checksum: raise SetupError('Google SDK 下载清单格式异常。')
            file=stage/'sdk.zip'; unpack=stage/'unpack'; unpack.mkdir()
            download(repo+name,file,checksum,'sha1'); safe_zip(file,unpack)
            shutil.move(str(unpack/'cmdline-tools'),str(source))
        if not usable(source): raise SetupError('Android 命令行工具包结构异常或没有执行权限。')
        # Never overwrite an existing user installation, even if it is incomplete.
        target=commands/'latest'
        if target.exists() or target.is_symlink():
            target=commands/('codex-experiment-'+pathlib.Path(stage_dir).name.removeprefix('.codex-install-'))
        source.rename(target)
    return str(target/'bin/sdkmanager'),str(target/'bin/avdmanager')

def tool(sdk,*paths):
    for path in paths:
        p=sdk/path
        if p.is_file() and os.access(p,os.X_OK): return str(p)
    raise SetupError(f'Android SDK 安装后仍缺少 {paths[0]}；请查看准备过程.log。')

def ports(count):
    # Probe both emulator console and adb port; the emulator itself performs the final bind.
    answer=[]
    for p in range(5554, 5680, 2):
        sockets=[]
        try:
            for n in (p,p+1):
                s=socket.socket(); sockets.append(s); s.bind(('127.0.0.1',n))
            answer.append(p)
        except OSError: pass
        finally:
            for s in sockets: s.close()
        if len(answer)==count: return answer
    raise SetupError('找不到两个空闲模拟器端口。')

def booted(adb, serial, env, proc, seconds=360):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if proc.poll() is not None: raise SetupError(f'{serial} 模拟器提前退出，请查看其日志。')
        p=subprocess.run([adb,'-s',serial,'shell','getprop','sys.boot_completed'],env=env,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,timeout=10)
        if p.returncode==0 and p.stdout.strip()=='1': return
        time.sleep(3)
    raise SetupError(f'{serial} 在 {seconds} 秒内未完成启动。')

def timestamp(value):
    try:
        d=dt.datetime.fromisoformat(value.replace('Z','+00:00'))
        return d if d.tzinfo else None
    except (ValueError,TypeError,AttributeError): return None

def parse_telemetry(path):
    """Conservative parser: only send/receive with the same explicit communication_id."""
    ansi=re.compile(r'\x1b\[[0-9;]*m'); records=collections.defaultdict(lambda: {'send': [], 'receive': []})
    if not path.exists(): return []
    def val(line,key):
        m=re.search(r'\b'+re.escape(key)+r'\s*[=:]\s*(?:"([^"\n]*)"|([^\s,}\]]+))',line)
        return (m.group(1) or m.group(2)) if m else ''
    for n,raw in enumerate(path.read_text(encoding='utf-8',errors='replace').splitlines(),1):
        line=ansi.sub('',raw)
        if 'agent_communication' not in line: continue
        cid=val(line,'communication_id'); state=val(line,'state')
        t=re.search(r'\b\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)',line)
        if cid and state in ('send','receive'):
            records[cid][state].append({'time':t.group(0) if t else '', 'line':n, 'sender':val(line,'sender_thread_id'),'receiver':val(line,'receiver_thread_id'),'kind':val(line,'kind')})
    result=[]
    for cid,pair in records.items():
        a=pair['send']; b=pair['receive']; status='ok'; ms=''
        if len(a)!=1 or len(b)!=1: status='missing_or_duplicate_event'
        else:
            ta=timestamp(a[0]['time']); tb=timestamp(b[0]['time'])
            if ta is None or tb is None or tb<ta: status='invalid_timestamp'
            else: ms=round((tb-ta).total_seconds()*1000,3)
        one=a[0] if a else {}; two=b[0] if b else {}
        result.append({'communication_id':cid,'kind':one.get('kind',''),'sender_thread_id':one.get('sender',''),'receiver_thread_id':one.get('receiver',''),'send_utc':one.get('time',''),'receive_utc':two.get('time',''),'delivery_ms':ms,'status':status,'send_line':one.get('line',''),'receive_line':two.get('line','')})
    return result

def write_csv(path,fields,rows):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields); w.writeheader()
        for row in rows:
            w.writerow({k:("'"+v if isinstance(v,str) and v.lstrip().startswith(('=','+','-','@')) else v) for k,v in row.items()})

def stats(values):
    values=sorted(values)
    if not values: return '无可配对样本'
    percentile=lambda p: values[max(0,math.ceil(len(values)*p)-1)]
    result=f'样本 {len(values)}，中位数 {statistics.median(values):.3f} ms，最大 {values[-1]:.3f} ms'
    if len(values)>=20: result+=f'，P95 {percentile(.95):.3f} ms'
    if len(values)>=100: result+=f'，P99 {percentile(.99):.3f} ms'
    return result

def report(root, info):
    event_dir=root/'记录'; diag=[]; counts=collections.defaultdict(lambda:[0,0]); directions=collections.defaultdict(lambda:[0,0]); examples=[]; call_times=collections.defaultdict(list)
    try:
        with (event_dir/'消息明细.csv').open(encoding='utf-8-sig',newline='') as f:
            for row in csv.DictReader(f):
                key=row.get('事件','未知'); counts[key][0]+=1
                try:
                    size=int(row['UTF8字节']); counts[key][1]+=size
                    sender=row.get('发送方',''); receiver=row.get('接收方','')
                    if sender=='/root' and receiver not in ('/root','未知',''): direction='Leader → Worker'
                    elif receiver=='/root' and sender not in ('/root','未知',''): direction='Worker → Leader'
                    else: direction='方向未知或其他'
                    directions[direction][0]+=1; directions[direction][1]+=size
                    if len(examples)<12: examples.append((direction,key,row.get('消息内容','')[:300],row.get('来源文件',''),row.get('行号','')))
                except (KeyError,ValueError): diag.append('某条消息的字节数不可解析。')
    except OSError: diag.append('消息明细不存在：未能运行或分析 Codex。')
    try:
        with (event_dir/'调用耗时.csv').open(encoding='utf-8-sig',newline='') as f:
            for row in csv.DictReader(f):
                if row.get('measurement_status')=='ok':
                    try: call_times[row['tool']].append(float(row['duration_ms']))
                    except (KeyError,ValueError): pass
    except OSError: pass
    tele=parse_telemetry(event_dir/'codex-stderr.log')
    fields=['communication_id','kind','sender_thread_id','receiver_thread_id','send_utc','receive_utc','delivery_ms','status','send_line','receive_line']
    write_csv(root/'投递时间明细.csv',fields,tele)
    delivery=collections.defaultdict(list)
    for row in tele:
        if row['status']=='ok': delivery[row['kind'] or 'unknown'].append(row['delivery_ms'])
    info['telemetry_events_matched']=sum(len(v) for v in delivery.values())
    info['recognized_messages_by_tool']={k:{'count':v[0],'body_utf8_bytes':v[1]} for k,v in counts.items()}
    info['recognized_messages_by_direction']={k:{'count':v[0],'body_utf8_bytes':v[1]} for k,v in directions.items()}
    (root/'实验状态.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
    e=html.escape
    parts=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>Android 多 Agent 实验报告</title><style>body{font:16px/1.65 -apple-system,BlinkMacSystemFont,sans-serif;max-width:1000px;margin:40px auto;padding:0 20px;color:#1f2937}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:8px;text-align:left}code{background:#f1f5f9;padding:2px 4px}</style><h1>Android 多 Agent 实验报告</h1>']
    parts.append('<p>运行状态：<b>'+e(str(info.get('status','未知')))+'</b>。 '+e(str(info.get('detail','')))+'</p>')
    if info.get('failed_stage'): parts.append('<p>失败阶段：'+e(str(info['failed_stage']))+'</p>')
    parts.append('<p>应用和基线：Now in Android <code>'+APP_REV+'</code>；公开工作流：Android Bug Priority Tree <code>'+FLOW_REV+'</code>。应用与流程的组合、设备槽位属于本实验配置。</p>')
    parts.append('<h2>正式开发耗时</h2><p>只计 Codex 多 Agent 正式任务从启动到结束的时间；环境安装、下载、模拟器准备、基线构建和报告生成均不计入。工具调用时间可互相重叠，不能相加得到总耗时。</p><table><tr><th>阶段</th><th>秒</th><th>状态</th></tr>')
    if 'formal_elapsed_seconds' in info:
        parts.append('<tr><td>Codex 多 Agent 正式任务</td><td>'+e(str(info['formal_elapsed_seconds']))+'</td><td>'+e(str(info.get('formal_status','未知')))+'</td></tr>')
    else: parts.append('<tr><td colspan="3">尚未启动或未获得正式任务的有效计时，不能计算开发耗时。</td></tr>')
    parts.append('</table><h2>可识别消息正文</h2><p>按工具调用参数及支持格式的完成结果提取；调用不保证送达，未识别记录不等于零。明细包含发送方、接收方和来源行。自动通知、继承上下文、日志不支持的格式可能遗漏。</p><table><tr><th>事件</th><th>条数</th><th>正文 UTF-8 字节</th></tr>')
    for k,(n,b) in sorted(counts.items()): parts.append(f'<tr><td>{e(k)}</td><td>{n}</td><td>{b}</td></tr>')
    if not counts: parts.append('<tr><td colspan="3">没有可识别记录；不能据此判断真实通信量为零。</td></tr>')
    parts.append('</table><h3>通信方向与内容摘录</h3><p>仅在会话明确标识 /root 和对端时归类，无法判断的保留为未知；正文 UTF-8 字节不是网络流量字节，不包含协议开销、模型请求、文件内容和共享上下文。</p><table><tr><th>方向</th><th>条数</th><th>正文 UTF-8 字节</th></tr>')
    for k,(n,b) in sorted(directions.items()): parts.append(f'<tr><td>{e(k)}</td><td>{n}</td><td>{b}</td></tr>')
    if not directions: parts.append('<tr><td colspan="3">没有可分类的消息。</td></tr>')
    parts.append('</table><p>下列内容仅为前 12 条可识别记录的截取，具体用途须结合原始上下文人工判断。</p><table><tr><th>方向 / 事件</th><th>消息摘录</th><th>原始记录</th></tr>')
    for direction,kind,body,source,line in examples: parts.append('<tr><td>'+e(direction+' / '+kind)+'</td><td>'+e(body)+'</td><td>'+e(source+':'+str(line))+'</td></tr>')
    if not examples: parts.append('<tr><td colspan="3">无可展示消息。</td></tr>')
    parts.append('</table><h2>延迟拆分</h2><p>以下为同一会话内工具调用到其返回的时间差；wait 是等待工作结果，通常包括 Agent 工作、模型与排队时间。它们不是网络延迟。</p><table><tr><th>工具</th><th>统计</th></tr>')
    for k,v in sorted(call_times.items()): parts.append('<tr><td>'+e(k)+'</td><td>'+e(stats(v))+'</td></tr>')
    if not call_times: parts.append('<tr><td colspan="2">无可配对的工具调用时间。</td></tr>')
    parts.append('</table><h3>发送到接收事件</h3><p>仅在 Codex 的原始诊断中出现同一通信 ID 的唯一 send 和 receive、且时间有效时配对；时间包含本地排队与调度，不等于网络传输或应用端完整处理。日志版本可能不输出这些事件。</p><table><tr><th>类型</th><th>统计</th></tr>')
    for k,v in sorted(delivery.items()): parts.append('<tr><td>'+e(k)+'</td><td>'+e(stats(v))+'</td></tr>')
    if not delivery: parts.append('<tr><td colspan="2">当前未获得可配对投递事件，无法判断实际投递耗时。</td></tr>')
    parts.append('</table><h2>瓶颈判断</h2><p>本报告不会把模型推理时间、Worker 执行时间或 wait 耗时归因于通信。缺少完整投递时间、跨路径对照与足够样本时，无法判断 Leader–Worker 通信是否为主要瓶颈。模拟器资源采样是设备槽位级，不等于 Agent 或远端模型独占资源。</p>')
    parts.append('<h2>设备与核对</h2><p>本次仅当两个模拟器都启动、安装 APK 并通过非零 Android 测试后才开始 Codex。Agent 使用指定设备仍需逐条核对会话、测试日志与证据，设备启动不证明任务完成。入口、设备数据、失败及未完成内容见实验状态与安装日志。</p>')
    parts.append('<p>原始会话和报告可能包含源代码、截图或敏感信息。查看 <code>记录/消息明细.csv</code>、<code>记录/调用耗时.csv</code>、<code>投递时间明细.csv</code>、<code>记录/codex-stderr.log</code>、<code>设备资源.csv</code> 及原始会话核对。'+e(' '.join(diag))+'</p></html>')
    (root/'实验报告.html').write_text('\n'.join(parts),encoding='utf-8')

def sample_devices(procs,path,stop):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f); w.writerow(['utc','slot','pid','cpu_percent','rss_kib'])
        while not stop.is_set():
            now=dt.datetime.now(dt.timezone.utc).isoformat()
            for slot,p in procs:
                if p.poll() is not None: continue
                x=subprocess.run(['ps','-p',str(p.pid),'-o','%cpu=,rss='],capture_output=True,text=True)
                vals=x.stdout.split()
                if len(vals)>=2: w.writerow([now,slot,p.pid,vals[0],vals[1]])
            f.flush(); stop.wait(2)

def main():
    if sys.version_info < (3,9): raise SetupError('需要 Python 3.9 或更新版本。')
    root=pathlib.Path.home()/'codex-agent-experiments'/('android01-'+dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    root.mkdir(parents=True,exist_ok=False); print('本次实验目录：',root,flush=True)
    log=root/'准备过程.log'; info={'status':'准备中','app_url':APP_URL,'app_commit':APP_REV,'workflow_url':FLOW_URL,'workflow_commit':FLOW_REV,'devices':[],'launcher_started_utc':dt.datetime.now(dt.timezone.utc).isoformat()}
    processes=[]; files=[]; stop=threading.Event(); sampler=None; code=1
    @contextlib.contextmanager
    def phase(name):
        print('\n【'+name+'】',flush=True)
        try: yield
        except BaseException:
            info['failed_stage']=name; raise
    try:
        with phase('检查工具与登录'):
            if sys.platform=='darwin': os.environ['PATH']='/opt/homebrew/bin:/usr/local/bin:'+os.environ.get('PATH','')
            for name in ('git','python3'):
                if not shutil.which(name): raise SetupError(f'缺少 {name}；请先安装后重新运行。')
            cache=pathlib.Path.home()/'codex-agent-experiments/工具缓存'; cache.mkdir(parents=True,exist_ok=True)
            env=os.environ.copy(); env['npm_config_cache']=str(cache/'npm缓存')
            env=java21(env,cache); env=node22(env,cache)
            if not shutil.which('codex',path=env.get('PATH')):
                print('正在本次实验目录安装 Codex CLI。',flush=True)
                command(['npm','install','--prefix',str(root/'codex工具'),'--no-audit','--no-fund','@openai/codex'],env=env,logfile=log,timeout=900)
                env['PATH']=str(root/'codex工具/node_modules/.bin')+os.pathsep+env['PATH']
            sdk=locate_sdk(cache); env['ANDROID_HOME']=str(sdk); env['ANDROID_SDK_ROOT']=str(sdk)
            sdkmanager,avdmanager=prepare_sdk_manager(sdk,cache)
            abi='arm64-v8a' if os.uname().machine.lower() in ('arm64','aarch64') else 'x86_64'
            image='system-images;android-34;google_apis;'+abi
            needed=[]
            for rel,package in [('platform-tools/adb','platform-tools'),('emulator/emulator','emulator'),('platforms/android-36','platforms;android-36'),('system-images/android-34/google_apis/'+abi,image)]:
                if not (sdk/rel).exists(): needed.append(package)
            if needed:
                print('将自动安装缺少的 Android SDK 组件；如出现许可协议，请在窗口中阅读并选择。',flush=True)
                command([sdkmanager,'--sdk_root='+str(sdk),'--install',*needed],env=env,interactive=True,timeout=3600)
            adb=tool(sdk,'platform-tools/adb'); emulator=tool(sdk,'emulator/emulator')
            if subprocess.run(['codex','login','status'],env=env).returncode:
                print('请按 Codex 提示完成浏览器登录。',flush=True)
                command(['codex','login'],env=env,interactive=True)
                command(['codex','login','status'],env=env,interactive=True)
            info['codex_version']=subprocess.run(['codex','--version'],env=env,capture_output=True,text=True).stdout.strip()
            venv=root/'工具环境'; command([sys.executable,'-m','venv',str(venv)],logfile=log)
            py=venv/'bin/python'; command([str(py),'-m','pip','install','python-docx>=1.1,<2','Pillow>=10,<13'],logfile=log,env=env,timeout=600)
            if sys.platform!='darwin' and not shutil.which('magick',path=env.get('PATH')):
                helper=root/'辅助命令'; helper.mkdir()
                resize=helper/'magick'; resize.write_text('#!'+str(py)+'\nfrom PIL import Image\nimport sys\nif len(sys.argv)!=5 or sys.argv[2]!="-resize": raise SystemExit("仅支持 magick 输入 -resize 宽x高 输出")\nw,h=(int(x) for x in sys.argv[3].split("x")); image=Image.open(sys.argv[1]); image.thumbnail((w,h)); image.save(sys.argv[4])\n'); resize.chmod(0o755)
                env['PATH']=str(helper)+os.pathsep+env['PATH']
        with phase('准备设备操作服务'):
            command(['npm','install','--prefix',str(root/'设备工具'),'--no-audit','--no-fund','@mobilenext/mobile-mcp@1.0.17'],env=env,logfile=log,timeout=900)
            mcp=root/'设备工具/node_modules/.bin/mcp-server-mobile'
            if not mcp.is_file(): raise SetupError('设备操作服务安装后缺少可执行入口。')
            env['ANDROID_EXPERIMENT_MCP_COMMAND']=str(mcp)
            info['device_tool']='@mobilenext/mobile-mcp@1.0.17'
        with phase('准备 Android SDK 与两个模拟器'):
            avdhome=root/'设备数据'; avdhome.mkdir(); env['ANDROID_AVD_HOME']=str(avdhome); env['ANDROID_USER_HOME']=str(root/'android用户数据'); pathlib.Path(env['ANDROID_USER_HOME']).mkdir()
            command([adb,'start-server'],env=env,logfile=log,timeout=30)
            for idx,p in enumerate(ports(2)):
                name=f'research_{root.name.replace("-", "_")}_{idx+1}'; serial=f'emulator-{p}'
                command([avdmanager,'create','avd','-n',name,'-k',image],env=env,logfile=log,stdin='no\n',timeout=90)
                fh=(root/f'模拟器{idx+1}.log').open('w',encoding='utf-8'); files.append(fh)
                proc=subprocess.Popen([emulator,'-avd',name,'-port',str(p),'-no-window','-no-audio','-no-boot-anim','-no-snapshot-save'],env=env,stdout=fh,stderr=subprocess.STDOUT,start_new_session=True)
                processes.append((serial,proc)); info['devices'].append({'slot':idx+1,'avd':name,'serial':serial,'pid':proc.pid})
            sampler=threading.Thread(target=sample_devices,args=(processes,root/'设备资源.csv',stop),daemon=True); sampler.start()
            for serial,proc in processes: booted(adb,serial,env,proc)
        with phase('下载固定应用和公开工作流'):
            project=root/'应用'; flow=root/'公开工作流'
            for url,path,rev in ((APP_URL,project,APP_REV),(FLOW_URL,flow,FLOW_REV)):
                command(['git','clone','--filter=blob:none','--depth','1','--no-checkout',url,str(path)],logfile=log,timeout=900)
                command(['git','fetch','--depth','1','origin',rev],cwd=path,logfile=log,timeout=300)
                command(['git','checkout','--detach',rev],cwd=path,logfile=log,timeout=120)
                got=subprocess.check_output(['git','rev-parse','HEAD'],cwd=path,text=True).strip()
                if got != rev: raise SetupError('检出的 Git 版本与固定版本不一致。')
            skills=project/'.agents/skills'; skills.mkdir(parents=True,exist_ok=True)
            shutil.copytree(flow/'skills/android-bug-priority-tree',skills/'android-bug-priority-tree')
            # Existing project checkout is an isolated experiment copy.
            env['GRADLE_USER_HOME']=str(root/'Gradle缓存')
        with phase('构建应用和设备测试'):
            command(['./gradlew',':app:assembleDemoDebug',':app:assembleDemoDebugAndroidTest','--no-daemon'],cwd=project,env=env,logfile=log,timeout=2700)
            app_apks=list((project/'app/build/outputs/apk/demo/debug').glob('*.apk'))
            test_apks=list((project/'app/build/outputs/apk/androidTest/demo/debug').glob('*.apk'))
            if len(app_apks)!=1 or len(test_apks)!=1: raise SetupError(f'APK 数量不符合预期：应用 {len(app_apks)}，测试 {len(test_apks)}。')
            for serial,_ in processes:
                for apk in (app_apks[0],test_apks[0]): command([adb,'-s',serial,'install','-r',str(apk)],env=env,logfile=log,timeout=180)
                testlog=root/(serial+'-基线测试.log')
                with testlog.open('w',encoding='utf-8') as f:
                    p=subprocess.run([adb,'-s',serial,'shell','am','instrument','-w',APP_ID+'.test/com.google.samples.apps.nowinandroid.core.testing.NiaTestRunner'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=900)
                text=testlog.read_text(encoding='utf-8',errors='replace')
                match=re.search(r'OK\s*\(\s*(\d+)\s+tests?\s*\)',text)
                if p.returncode or not match or int(match.group(1))<1 or re.search(r'FAILURES!!!|INSTRUMENTATION_FAILED|INSTRUMENTATION_ABORTED',text):
                    raise SetupError(f'{serial} 的基线设备测试未验证成功，请查看 {testlog}。')
                info['devices'][int(serial==processes[1][0])]['baseline_tests']=int(match.group(1))
        with phase('运行真实 Codex 多 Agent'):
            serials=[p[0] for p in processes]
            prompt=f'''请使用原生多 Agent 工具，按仓库内 $android-bug-priority-tree 公开工作流测试并修复当前 Now in Android demoDebug 应用。项目是隔离副本。\n先阅读项目 AGENTS.md 与该 skill。你是 Leader，负责规划、分派、结果收集、集成与汇报。先建立用户旅程地图；并行启动两个设备测试 Worker，分别负责 For You、Interests / Bookmarks 的真实用户路径，每个 Worker 必须获取以下互不重叠的设备槽位之一：{serials[0]}、{serials[1]}。每个涉及设备的子 Agent 指令必须写明唯一 serial，所有 adb 操作显式使用 adb -s SERIAL；严禁两个并发 Worker 操作同一设备，后续确认、修复和独立验证按空闲槽位排队。Worker 必须在自己的模拟器执行真实交互或设备测试、提供命令与结果、对应设备 serial、问题及证据路径；未执行必须标记未执行，不能伪造。测试需用 demo 的本地数据，不访问真实生产服务，不使用个人账号。\n遵循公开工作流：报告候选、独立确认；仅在发现且确认真实缺陷时分派修复，修复须带回归测试，集成后由不同 Worker 独立复验。无缺陷时如实报告，禁止人为制造缺陷或为通信量填充消息。所有 Worker 需要清楚报告任务、消息和状态；Leader 汇总命令、通过失败数量、代码更改、设备证据和限制。不推送或发布。当前目录为实验副本，允许本地修改与工作流所需的本地提交。\n'''
            (root/'本次任务.txt').write_text(prompt,encoding='utf-8')
            runner=root/'runner.py'
            source=zlib.decompress(base64.b64decode(RUNNER)).decode('utf-8')
            needle="    cmd.append('-')"
            addition="    if os.environ.get('ANDROID_EXPERIMENT_MCP_COMMAND'):\n        cmd.extend(['-c', 'mcp_servers.mobile-mcp.command=' + json.dumps(os.environ['ANDROID_EXPERIMENT_MCP_COMMAND']), '-c', 'sandbox_workspace_write.network_access=true'])\n"
            if source.count(needle)!=1: raise SetupError('内置采集器配置入口不匹配。')
            runner.write_text(source.replace(needle,addition+needle),encoding='utf-8')
            env['RUST_LOG']=(env.get('RUST_LOG','error')+',codex_otel.agent_communication=info')
            env['PATH']=str(sdk/'platform-tools')+os.pathsep+str(sdk/'emulator')+os.pathsep+env['PATH']
            p=subprocess.run([str(py),str(runner),'--project',str(project),'--mode','write','--timeout','7200','--prompt',str(root/'本次任务.txt'),'--output',str(root/'记录')],env=env)
            info['codex_exit_code']=p.returncode
            meta_path=root/'记录/实验信息.json'
            meta=json.loads(meta_path.read_text(encoding='utf-8')) if meta_path.exists() else {}
            if meta.get('exit_code')!=127 and isinstance(meta.get('elapsed_seconds'),(int,float)):
                info['formal_elapsed_seconds']=meta['elapsed_seconds']
                info['formal_status']='完成' if not p.returncode else '失败或中断'
            if p.returncode: raise SetupError(f'Codex 未成功完成（退出码 {p.returncode}）；请查看 记录/codex-stderr.log。')
            info['session_count']=meta.get('session_count',0); info['recognized_messages']=meta.get('recognized_messages',0)
            if info['session_count']<3 or info['recognized_messages']<1:
                raise SetupError('未关联到至少两个子会话或未识别到协作消息；不能判定多 Agent 测试完成，请检查原始会话。')
            info['status']='Codex 已结束，待人工核对设备使用和 Agent 结果'; code=0
    except KeyboardInterrupt:
        info['status']='用户中断'; info['detail']='实验中断；保留已产生的日志。'; code=130
    except (SetupError, OSError, subprocess.SubprocessError, ValueError, tarfile.TarError, zipfile.BadZipFile, ET.ParseError) as e:
        info['status']='未完成'; info['detail']=str(e); print('\n未完成：',e,flush=True); code=1
    finally:
        stop.set()
        if sampler: sampler.join(timeout=5)
        for serial,proc in processes:
            if proc.poll() is None:
                try: os.killpg(proc.pid,signal.SIGTERM)
                except ProcessLookupError: pass
        for serial,proc in processes:
            try: proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                try: os.killpg(proc.pid,signal.SIGKILL)
                except ProcessLookupError: pass
                proc.wait()
        for f in files: f.close()
        info['finished_utc']=dt.datetime.now(dt.timezone.utc).isoformat()
        report(root,info)
        print('\n实验报告：',root/'实验报告.html',flush=True)
        if sys.platform=='darwin': subprocess.run(['open',str(root/'实验报告.html')],check=False)
    return code

if __name__=='__main__':
    try: rc=main()
    except Exception as exc:
        print('启动失败：',exc,file=sys.stderr); rc=1
    if sys.stdin.isatty():
        try: input('\n按回车关闭窗口…')
        except (EOFError,KeyboardInterrupt): pass
    sys.exit(rc)
