# MYSQL-SAMP-TH

[![sampctl](https://img.shields.io/badge/sampctl-MYSQL--SAMP--TH-2f2f2f.svg?style=for-the-badge)](https://github.com/JIRATHXT/MYSQL-SAMP-TH)

<!--
Short description of your library, why it's useful, some examples, pictures or
videos. Link to your forum release thread too.

Remember: You can use "forumfmt" to convert this readme to forum BBCode!

What the sections below should be used for:

`## Installation`: Leave this section un-edited unless you have some specific
additional installation procedure.

`## Testing`: Whether your library is tested with a simple `main()` and `print`,
unit-tested, or demonstrated via prompting the player to connect, you should
include some basic information for users to try out your code in some way.

And finally, maintaining your version number`:

* Follow [Semantic Versioning](https://semver.org/)
* When you release a new version, update `VERSION` and `git tag` it
* Versioning is important for sampctl to use the version control features

Happy Pawning!
-->
# !!! ของฟรีห้ามนำไปขายเด็ดขาด !!!

## คุณต้องมี SAMPCTL & XAMPP
### https://github.com/Southclaws/sampctl/wiki
### https://www.apachefriends.org/download.html

## ติดตั้ง

ติดตั้งฐานข้อมูล :

1. เข้า XAMPP
2. เปิด Apache & MYSQL
3. ไปที่ 127.0.0.1/phpmyadmin
4. กด New & ตั้งชื่อว่า samp
5. กดแถบ SQL
6. คัดลอกด้านล่างไปใส่ และกด Go
```SQL
CREATE TABLE IF NOT EXISTS `players` (`id` int(11) NOT NULL AUTO_INCREMENT,`username` varchar(24) NOT NULL,`x` float NOT NULL DEFAULT '0',`y` float NOT NULL DEFAULT '0',`z` float NOT NULL DEFAULT '0',`angle` float NOT NULL DEFAULT '0',`interior` tinyint(3) NOT NULL DEFAULT '0', PRIMARY KEY (`id`), UNIQUE KEY `username` (`username`))
```

คำสั่งติดตั้งโปรเจค:

```bash
git clone https://github.com/JIRATHXT/MYSQL-SAMP-TH && cd MYSQL-SAMP-TH
```
```bash
sampctl p ensure
```

<!--
Write your code documentation or examples here. If your library is documented in
the source code, direct users there. If not, list your API and describe it well
in this section. If your library is passive and has no API, simply omit this
section.
-->

## คำสั่ง

<!--
Depending on whether your package is tested via in-game "demo tests" or
y_testing unit-tests, you should indicate to readers what to expect below here.
-->

ติดตั้งแพ็คเกจ :

```bash
sampctl p install < ลิงก์ Project Github >
```

ลบแพ็คเกจ :

```bash
sampctl p uninstall < ลิงก์ Project Github >
```

คอมไพสคริปต์ :

```bash
sampctl p build
```

เช็คหรืออัพเดตแพ็คเก็จ :

```bash
sampctl p ensure
```

เปิดเซิร์ฟ :

```bash
sampctl p run
```
