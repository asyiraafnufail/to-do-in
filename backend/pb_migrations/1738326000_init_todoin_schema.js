/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const findCol = (name) => {
    try {
      return app.findCollectionByNameOrId(name)
    } catch (_) {
      return null
    }
  }

  // 1. users (Auth — bawaan PocketBase)
  const users = app.findCollectionByNameOrId("users")
  users.listRule = ""
  users.viewRule = ""
  users.createRule = ""
  users.updateRule = "@request.auth.id = id && (@request.body.is_verified_host:isset = false || @request.body.is_verified_host = is_verified_host)"
  users.deleteRule = "@request.auth.id = id"

  users.fields.add(new TextField({
    name: "username",
    required: true,
    min: 3,
    max: 20,
    pattern: "^[a-z0-9._]+$",
    autogeneratePattern: "user_[a-z0-9]{8}",
  }))
  users.fields.add(new TextField({
    name: "bio",
    max: 160,
  }))
  users.fields.add(new TextField({
    name: "whatsapp",
    max: 30,
  }))
  users.fields.add(new TextField({
    name: "instagram",
    max: 60,
  }))
  users.fields.add(new SelectField({
    name: "contact_privacy",
    values: ["public", "followers", "hidden"],
    maxSelect: 1,
  }))
  users.fields.add(new BoolField({
    name: "is_verified_host",
  }))
  users.addIndex("idx_users_username", true, "username", "")
  app.save(users)

  // 2. posts
  let posts = findCol("posts")
  if (!posts) {
    posts = new Collection({
      type: "base",
      name: "posts",
      listRule: "",
      viewRule: "",
      createRule: "@request.auth.id != '' && @request.body.author = @request.auth.id",
      updateRule: "@request.auth.id = author",
      deleteRule: "@request.auth.id = author",
      fields: [
        {
          name: "author",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          required: true,
          cascadeDelete: true,
        },
        {
          name: "title",
          type: "text",
          required: true,
          max: 200,
        },
        {
          name: "slug",
          type: "text",
          required: true,
          max: 220,
          autogeneratePattern: "[a-z0-9]{12}",
        },
        {
          name: "content",
          type: "editor",
          required: true,
        },
        {
          name: "images",
          type: "file",
          maxSelect: 5,
          maxSize: 524288,
          mimeTypes: ["image/jpeg", "image/webp", "image/png"],
          thumbs: ["400x300", "800x600"],
        },
        {
          name: "category",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["Kuliner", "Alam", "Budaya", "Hidden Gem", "Penginapan"],
        },
        {
          name: "place_name",
          type: "text",
          max: 160,
        },
        {
          name: "city",
          type: "text",
          required: true,
          max: 100,
        },
        {
          name: "province",
          type: "text",
          required: true,
          max: 100,
        },
        {
          name: "is_live_gps",
          type: "bool",
        },
        {
          name: "lat_approx",
          type: "number",
        },
        {
          name: "lng_approx",
          type: "number",
        },
        {
          name: "todo_items",
          type: "json",
        },
        {
          name: "is_edited",
          type: "bool",
        },
        {
          name: "created",
          type: "autodate",
          onCreate: true,
          onUpdate: false,
        },
        {
          name: "updated",
          type: "autodate",
          onCreate: true,
          onUpdate: true,
        },
      ],
    })
    posts.addIndex("idx_posts_slug", true, "slug", "")
    app.save(posts)
  }

  // 3. user_todos
  if (!findCol("user_todos")) {
    const userTodos = new Collection({
      type: "base",
      name: "user_todos",
      listRule: "@request.auth.id = user",
      viewRule: "@request.auth.id = user",
      createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
      updateRule: "@request.auth.id = user",
      deleteRule: "@request.auth.id = user",
      fields: [
        {
          name: "user",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          required: true,
          cascadeDelete: true,
        },
        {
          name: "source_post",
          type: "relation",
          collectionId: posts.id,
          maxSelect: 1,
        },
        {
          name: "city",
          type: "text",
          required: true,
          max: 100,
        },
        {
          name: "task_title",
          type: "text",
          required: true,
          max: 250,
        },
        {
          name: "notes",
          type: "text",
          max: 500,
        },
        {
          name: "is_completed",
          type: "bool",
        },
        {
          name: "created",
          type: "autodate",
          onCreate: true,
          onUpdate: false,
        },
        {
          name: "updated",
          type: "autodate",
          onCreate: true,
          onUpdate: true,
        },
      ],
    })
    app.save(userTodos)
  }

  // 4. listings
  if (!findCol("listings")) {
    const listings = new Collection({
      type: "base",
      name: "listings",
      listRule: "",
      viewRule: "",
      createRule: "@request.auth.is_verified_host = true && @request.body.owner = @request.auth.id",
      updateRule: "@request.auth.id = owner",
      deleteRule: "@request.auth.id = owner",
      fields: [
        {
          name: "owner",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          required: true,
          cascadeDelete: true,
        },
        {
          name: "type",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["open_trip", "vehicle", "stay"],
        },
        {
          name: "title",
          type: "text",
          required: true,
          max: 200,
        },
        {
          name: "description",
          type: "editor",
          required: true,
        },
        {
          name: "price",
          type: "number",
          required: true,
          min: 0,
        },
        {
          name: "price_unit",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["pax", "day", "night", "month"],
        },
        {
          name: "city",
          type: "text",
          required: true,
          max: 100,
        },
        {
          name: "province",
          type: "text",
          required: true,
          max: 100,
        },
        {
          name: "images",
          type: "file",
          maxSelect: 6,
          maxSize: 524288,
          mimeTypes: ["image/jpeg", "image/webp", "image/png"],
          thumbs: ["400x300", "800x600"],
        },
        {
          name: "specs",
          type: "json",
        },
        {
          name: "is_available",
          type: "bool",
        },
        {
          name: "created",
          type: "autodate",
          onCreate: true,
          onUpdate: false,
        },
        {
          name: "updated",
          type: "autodate",
          onCreate: true,
          onUpdate: true,
        },
      ],
    })
    app.save(listings)
  }

  // 5. kyc_requests
  if (!findCol("kyc_requests")) {
    const kycRequests = new Collection({
      type: "base",
      name: "kyc_requests",
      listRule: null,
      viewRule: "@request.auth.id = user",
      createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id && (@request.body.status:isset = false || @request.body.status = 'pending')",
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          name: "user",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          required: true,
          cascadeDelete: true,
        },
        {
          name: "id_card",
          type: "file",
          maxSelect: 1,
          maxSize: 5242880,
          mimeTypes: ["image/jpeg", "image/webp", "image/png"],
          protected: true,
          required: true,
        },
        {
          name: "selfie",
          type: "file",
          maxSelect: 1,
          maxSize: 5242880,
          mimeTypes: ["image/jpeg", "image/webp", "image/png"],
          protected: true,
          required: true,
        },
        {
          name: "asset_proof",
          type: "file",
          maxSelect: 1,
          maxSize: 5242880,
          mimeTypes: ["image/jpeg", "image/webp", "image/png", "application/pdf"],
          protected: true,
        },
        {
          name: "status",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["pending", "approved", "rejected"],
        },
        {
          name: "admin_note",
          type: "text",
          max: 500,
        },
        {
          name: "created",
          type: "autodate",
          onCreate: true,
          onUpdate: false,
        },
        {
          name: "updated",
          type: "autodate",
          onCreate: true,
          onUpdate: true,
        },
      ],
    })
    app.save(kycRequests)
  }

  // 6. social_actions
  if (!findCol("social_actions")) {
    const socialActions = new Collection({
      type: "base",
      name: "social_actions",
      listRule: "",
      viewRule: "",
      createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
      updateRule: "@request.auth.id = user",
      deleteRule: "@request.auth.id = user",
      fields: [
        {
          name: "user",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          required: true,
          cascadeDelete: true,
        },
        {
          name: "target_post",
          type: "relation",
          collectionId: posts.id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: "target_user",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: "action_type",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["like", "bookmark", "follow", "comment"],
        },
        {
          name: "comment_body",
          type: "text",
          max: 1000,
        },
        {
          name: "created",
          type: "autodate",
          onCreate: true,
          onUpdate: false,
        },
        {
          name: "updated",
          type: "autodate",
          onCreate: true,
          onUpdate: true,
        },
      ],
    })
    app.save(socialActions)
  }
}, (app) => {
  for (const name of ["social_actions", "kyc_requests", "listings", "user_todos", "posts"]) {
    try {
      app.delete(app.findCollectionByNameOrId(name))
    } catch (_) {}
  }

  try {
    const users = app.findCollectionByNameOrId("users")
    users.removeIndex("idx_users_username")
    for (const f of ["username", "bio", "whatsapp", "instagram", "contact_privacy", "is_verified_host"]) {
      users.fields.removeByName(f)
    }
    app.save(users)
  } catch (_) {}
})
