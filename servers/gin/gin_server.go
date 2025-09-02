// servers/gin_server.go
package main

import (
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
)

type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

func main() {
	port := "3002"
	if len(os.Args) > 1 {
		port = os.Args[1]
	}

	// Set Gin to release mode for benchmarking
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()

	// Simple hello world
	r.GET("/", func(c *gin.Context) {
		c.String(http.StatusOK, "Hello, World!")
	})

	// JSON response
	r.GET("/json", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Hello, World!",
			"status":  "success",
		})
	})

	// URL params
	r.GET("/user/:id", func(c *gin.Context) {
		idStr := c.Param("id")
		id, err := strconv.Atoi(idStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID"})
			return
		}

		user := User{
			ID:    id,
			Name:  "John Doe",
			Email: "john@example.com",
		}
		c.JSON(http.StatusOK, user)
	})

	// Query parameters
	r.GET("/search", func(c *gin.Context) {
		query := c.DefaultQuery("q", "default")
		limitStr := c.DefaultQuery("limit", "10")
		limit, _ := strconv.Atoi(limitStr)

		c.JSON(http.StatusOK, gin.H{
			"query":   query,
			"limit":   limit,
			"results": []string{"result1", "result2", "result3"},
		})
	})

	// POST with JSON body
	r.POST("/user", func(c *gin.Context) {
		var user User
		if err := c.ShouldBindJSON(&user); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		user.ID = 123
		c.JSON(http.StatusCreated, user)
	})

	// Form data
	r.POST("/form", func(c *gin.Context) {
		name := c.PostForm("name")
		email := c.PostForm("email")

		c.JSON(http.StatusOK, gin.H{
			"name":    name,
			"email":   email,
			"message": "Form received",
		})
	})

	log.Printf("Gin server starting on port %s", port)
	log.Fatal(r.Run(":" + port))
}
