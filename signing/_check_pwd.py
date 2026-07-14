import re
p = open(r"D:\oh-ai-car-ros-app\build-profile.json5", encoding="utf-8").read()
for m in re.finditer(r'"(storePassword|keyPassword)"\s*:\s*"([^"]*)"', p):
    s = m.group(2)
    print(m.group(1), "len=", len(s), "mod2=", len(s) % 2)
