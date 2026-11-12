/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const kyc = app.findCollectionByNameOrId("kyc_requests")
  kyc.listRule = "@request.auth.id = user"
  app.save(kyc)
}, (app) => {
  const kyc = app.findCollectionByNameOrId("kyc_requests")
  kyc.listRule = null
  app.save(kyc)
})
