# reg-ru-bash
Bash hook for dehydrated Let's Encrypt client for Reg.ru

У reg.ru принудительно выставлен TTL на все записи >= 1h, раньше это можно было менять через API, что и делал мой хук. 
Сейчас не меняется никак, из-за чего приходится использовать отвратительные костыли.

В общем, ситуация следующая — нужно в DNS создавать CNAME-запись на каждый домен, для которого нужно получать сертификаты с авторизацией по DNS.
и эти CNAME направлять либо на какой-нибудь DNS-хостинг с нормальным API (например, Cloudflare), либо, если такой возможности нет, на свой сервер, на который ставить bind9, обслуживающий только эту зону.

в `/etc/dehydrated/config/`
добавляется это:
```
export REGRU_url="https://api.reg.ru/api/regru2/zone"
export REGRU_user="логинрегру"
export REGRU_pass="парольрегру"
```

и это:
```
export NS_secret="secret"
export NS_pass="password"
export NS_server="111.222.222.111"
export NS_zone="auth.rokiroki.ru"
```

у меня сделано так:
1. в reg.ru сделана запись NS, ведущая на мой сервер с bind9 (auth.rokiroki.ru)
2. bind9 настроен на обслуживание этой доменной зоны
3. хук идёт на reg.ru и добавляет там CNAME-записи вида _acme-challenge.rokiroki.ru, ссылающиеся на auth.rokiroki.ru
4. дальше хук вписывает в bind9 текстовые записи, которые ждёт Let's Encrypt и на этом всё.

т.е. нужно:
1. сервер с bind9 ([настроенный примерно так](https://xn--90aeniddllys.xn--p1ai/dinamicheskoe-izmenenie-dns-zapisej-v-bind/), я уже не помню подробностей, главное, чтобы команда `nsupdate -k /etc/bind/key/dnsupdater.key` добавляла и удаляла записи)

2. NS-запись в reg.ru, ведущая на этот сервер

3. сам хук

Пример использования:
```
dehydrated -c -t dns-01 -k '/var/lib/dehydrated/hooks/reg_ru_named.sh' -d rokiroki.ru -d *.rokiroki.ru
```