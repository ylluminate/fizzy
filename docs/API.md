# Fizzy API

Fizzy has an API that allows you to integrate your application with it or to create
a bot to perform various actions for you.

## Authentication

To use the API you'll need an access token. To get one, go to your profile, then,
in the API section, click on "Personal access tokens" and then click on
"Generate new access token".

Pick what kind of permission you want the access token to have:
- `Read`: allows reading data from your account
- `Read + Write`: allows reading and writing data to your account on your behalf

> [!IMPORTANT]
> __An access token is like a password, keep it secret and do not share it with anyone.__
> Any person or application that has your access token can perform actions on your behalf.

To authenticate a request using your access token, include it in the `Authorization` header:

```bash
curl -H "Authorization: Bearer put-your-access-token-here" -H "Accept: application/json" https://app.fizzy.do/identity
```

## Caching

Most endpoints return [ETag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/ETag) and [Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control) headers. You can use these to avoid re-downloading unchanged data.

### Using ETags

When you make a request, the response includes an `ETag` header:

```
HTTP/1.1 200 OK
ETag: "abc123"
Cache-Control: max-age=0, private, must-revalidate
```

On subsequent requests, include the ETag value in the `If-None-Match` header:

```
GET /1234567/cards/42.json
If-None-Match: "abc123"
```

If the resource hasn't changed, you'll receive a `304 Not Modified` response with no body, saving bandwidth and processing time:

```
HTTP/1.1 304 Not Modified
ETag: "abc123"
```

If the resource has changed, you'll receive the full response with a new ETag.

__Example in Ruby:__

```ruby
# Store the ETag from the response
etag = response.headers["ETag"]

# On next request, send it back
headers = { "If-None-Match" => etag }
response = client.get("/1234567/cards/42.json", headers: headers)

if response.status == 304
  # Nothing to do, the card hasn't changed
else
  # The card has changed, process the new data
end
```

## Pagination

All endpoints that return a list of items are paginated. The page size can vary from endpoint to endpoint,
and we use a dynamic page size where initial pages return fewer results than later pages.

If there are more results to fetch, the response will include a `Link` header with a `rel="next"` link to the next page of results:

```bash
curl -H "Authorization: Bearer put-your-access-token-here" -H "Accept: application/json" -v http://fizzy.localhost:3006/686465299/cards
# ...
< link: <http://fizzy.localhost:3006/686465299/cards?page=2>; rel="next"
# ...
```

## Endpoints

### Identity

An Identity represents a person using Fizzy, their email address and their users in different accounts.

#### `GET /identity`

Returns a list of accounts, including the User, the Identity has access to

```json
{
  "accounts": [
    {
      "id": "03f5v9zjskhcii2r45ih3u1rq",
      "name": "37signals",
      "slug": "/897362094",
      "created_at": "2025-12-05T19:36:35.377Z",
      "user": {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:35.401Z",
        "url": "http://fizzy.localhost:3006/users/03f5v9zjw7pz8717a4no1h8a7"
      }
    },
    {
      "id": "03f5v9zpko7mmhjzwum3youpp",
      "name": "Honcho",
      "slug": "/686465299",
      "created_at": "2025-12-05T19:36:36.746Z",
      "user": {
        "id": "03f5v9zppzlksuj4mxba2nbzn",
        "name": "David Heinemeier Hansson",
        "role": "owner",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:36.783Z",
        "url": "http://fizzy.localhost:3006/users/03f5v9zppzlksuj4mxba2nbzn"
      }
    }
  ]
}
```

### Boards

Boards are where you organize your work - they contain your cards.

#### `GET /:account_slug/boards`

Returns a list of Boards, that you can access, in the specified account.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Fizzy",
    "all_access": true,
    "created_at": "2025-12-05T19:36:35.534Z",
    "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "role": "owner",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    }
  }
]
```

#### `GET /:account_slug/boards/:board_id`

Returns the specific Board.

__Response:__

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "Fizzy",
  "all_access": true,
  "created_at": "2025-12-05T19:36:35.534Z",
  "url": "http://fizzy.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
  "creator": {
    "id": "03f5v9zjw7pz8717a4no1h8a7",
    "name": "David Heinemeier Hansson",
    "role": "owner",
    "active": true,
    "email_address": "david@example.com",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://fizzy.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  }
}
```

#### `POST /:account_slug/boards`

Creates a new Board in the account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | The name of the board |
| `all_access` | boolean | No | Whether any user in the account can access this board. Defaults to `true` |
| `auto_postpone_period` | integer | No | Number of days of inactivity before cards are automatically postponed |
| `public_description` | string | No | Rich text description shown on the public board page |

__Request:__

```json
{
  "board": {
    "name": "My new board",
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new board:

```
HTTP/1.1 201 Created
Location: /897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm.json
```

#### `PUT /:account_slug/boards/:board_id`

Updates a Board. Only board administrators can update a board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The name of the board |
| `all_access` | boolean | No | Whether any user in the account can access this board |
| `auto_postpone_period` | integer | No | Number of days of inactivity before cards are automatically postponed |
| `public_description` | string | No | Rich text description shown on the public board page |
| `user_ids` | array | No | Array of *all* user IDs who should have access to this board (only applicable when `all_access` is `false`) |

__Request:__

```json
{
  "board": {
    "name": "Updated board name",
    "auto_postpone_period": 14,
    "public_description": "This is a **public** description of the board.",
    all_access: false,
    "user_ids": [
      "03f5v9zppzlksuj4mxba2nbzn",
      "03f5v9zjw7pz8717a4no1h8a7"
    ]
  }
}
```

__Response:__

Returns `204 No Content` on success.

#### `DELETE /:account_slug/boards/:board_id`

Deletes a Board. Only board administrators can delete a board.

__Response:__

Returns `204 No Content` on success.

### Cards

Cards represent tasks or items of work on a board
