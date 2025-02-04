# Mosquitto Go Auth Plugin for OAuth2

This is a custom backend for the [mosquitto go auth plugin](https://github.com/iegomez/mosquitto-go-auth) that can handle the authentification and authorization with a oauth2 server.

## Build it

Clone repo and build like this:

```bash
git clone https://github.com/innogon/mosquitto-go-auth-oauth2.git
cd mosquitto-go-auth-oauth2
docker build -t oauth2_broker .
docker run -it -p 1884:1884 -p 1883:1883 -v $PWD/example_conf:/etc/mosquitto oauth2_broker
```

Setup Keycloak like shown in chapter "Configure Keycloak via RestAPI". Then run somethink like MQTT.fx to check if it´s working like you expect.

## What about the script start.sh ?

The broker initializes an oauth2 session with Keycloak on startup. Keycloak by default times out any oauth2 session after 10hr. So the session can´t be prolonged with the refresh token. Step one for us was to increase this 10hr limit to 26hr. And step two was to restart the broker each 24hrs. The script ends the mosquitto binary after 24hrs. It´s getting restarted by the docker-compose restart policy. In the meantime the script checks if the broker is still alive an restarts it in case of a crash.

## How to use

This plugin use oauth to authenticate and authorize users for a mqtt broker. Unfornatly is it necassary, that the oauth server response with allowed topics for the user. So the authentication is simple and possible with all kinds of oauth servers. But for the acl check, server have to answer with a special json on the userinfo endpoint. This is the structur: 

```json
{
    "mqtt": {
        "topics": {
            "read": ["sensor/+/rx"],
            "write": ["application/#", "server_log/mqtt_broker/tx"],
        },
        "superuser": false,
    },
}

```

We use Keycloak and there you can customize your userinfo.

## Configure Keycloak via RestAPI

If keylcoak is configured that way, the mosquitto broker don´t need any entries in the acl or password file. All the user permissions will be checked by SSO.

Create the *client*:

```json
base_url = "https://mykeycloak.tld/auth/admin/realms/admin/clients"
msg.method = "POST"

msg.payload = {
    "name": "mqtt_broker",
    "id": "mqtt_broker",
    "protocol": "openid-connect",
    "publicClient": false,
    "protocolMappers": [
        {
            "name": "mqtt_read",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-attribute-mapper",
            "consentRequired": false,
            "config": {
                "multivalued": false,
                "userinfo.token.claim": true,
                "user.attribute": "mqtt_read",
                "id.token.claim": false,
                "access.token.claim": false,
                "claim.name": "mqtt.topics.read",
                "jsonType.label": "JSON"
            }
        },
                {
            "name": "mqtt_write",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-attribute-mapper",
            "consentRequired": false,
            "config": {
                "multivalued": false,
                "userinfo.token.claim": true,
                "user.attribute": "mqtt_write",
                "id.token.claim": false,
                "access.token.claim": false,
                "claim.name": "mqtt.topics.write",
                "jsonType.label": "JSON"
            }
        },
                {
            "name": "mqtt_superuser",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-attribute-mapper",
            "consentRequired": false,
            "config": {
                "multivalued": false,
                "userinfo.token.claim": true,
                "user.attribute": "mqtt_superuser",
                "id.token.claim": true,
                "access.token.claim": true,
                "claim.name": "mqtt.superuser",
                "jsonType.label": "String"
            }
        }
    ]
}
```

And then create the *user*:

```json
msg.url = "https://mykeycloak.tld/auth/admin/realms/myrealm/users"
msg.method = "POST"
msg.payload = {
    "username": "test",
    "firstName": "Vornamen",
    "lastName": "Nachname",
    "email": "user@mail.com",
    "groups": ["customers_heating"],
    "enabled": true,
    "attributes": {
        "mqtt_read": '["path1", "path2", "#/"]',
        "mqtt_write": '["path1", "path2"]',
        "mqtt_superuser": false
    },
    "credentials": [
        {
            "type": "password",
            "temporary": false,
            "value": "test"
        }
    ]
}
```

Then check endpoint for userinfo when logged in as user "test" via oauth2:

```json
msg.url = "https://mykeycloak.tld/auth/realms/myrealm/protocol/openid-connect/userinfo"
msg.method = "GET"
msg.payload = {}
```

## How to test

The simplest way is to use the delivered dockerfile and build your own image. You can use volumes to import the configurations or copy the files in the images while you build it.
If you use volumes you have to remove the `COPY` commands from the Dockerfile.
