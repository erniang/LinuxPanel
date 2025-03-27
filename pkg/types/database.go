package types

import (
    "time"
)

// Database 数据库类型
type Database struct {
    Name      string    `json:"name"`
    Charset   string    `json:"charset"`
    Collation string    `json:"collation"`
    Size      int64     `json:"size"`
    Tables    int       `json:"tables"`
    CreatedAt time.Time `json:"created_at"`
}

// DBUser 数据库用户
type DBUser struct {
    Username   string   `json:"username"`
    Host       string   `json:"host"`
    Databases  []string `json:"databases"`
    Privileges []string `json:"privileges"`
} 