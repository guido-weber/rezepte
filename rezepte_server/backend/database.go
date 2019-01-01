package backend

import (
	"context"
	"database/sql"
	"time"
)

// DB is the global database connection pool
var DB *sql.DB

// InitDB is called to initialize DB
func InitDB(driver string, dsn string) {
	db, err := sql.Open(driver, dsn)
	if err != nil {
		panic(err.Error())
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		panic(err.Error())
	}
	DB = db
}
