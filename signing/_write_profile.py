# -*- coding: utf-8 -*-
enc = open(r"D:/oh-ai-car-ros-app/signing/_enc.txt", encoding="utf-8").read().strip()
assert len(enc) >= 32 and len(enc) % 2 == 0, (len(enc), len(enc) % 2)
text = """{
  "app": {
    "signingConfigs": [
      {
        "name": "default",
        "material": {
          "storeFile": "D:/oh-ai-car-ros-app/signing/app.p12",
          "storePassword": "%s",
          "keyAlias": "debugKey",
          "keyPassword": "%s",
          "signAlg": "SHA256withECDSA",
          "profile": "D:/oh-ai-car-ros-app/signing/app.p7b",
          "certpath": "D:/oh-ai-car-ros-app/signing/app.cer"
        }
      }
    ],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "compileSdkVersion": 12,
        "compatibleSdkVersion": 12,
        "targetSdkVersion": 12,
        "runtimeOS": "OpenHarmony"
      }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default",
          "applyToProducts": [
            "default"
          ]
        }
      ]
    },
    {
      "name": "Rocker",
      "srcPath": "./Rocker",
      "targets": [
        {
          "name": "default",
          "applyToProducts": [
            "default"
          ]
        }
      ]
    }
  ]
}
""" % (enc, enc)
open(r"D:/oh-ai-car-ros-app/build-profile.json5", "w", encoding="utf-8").write(text)
print("ok enc_len", len(enc))
