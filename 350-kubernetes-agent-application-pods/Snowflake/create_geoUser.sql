use geo
db.createUser(
  {
    user: "geoUser",
    pwd: "ctmfy20",
    roles: [
       { role: "readWrite", db: "geo" }
    ]
  }
)