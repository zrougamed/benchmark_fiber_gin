// servers/fiber_v3.go
package main

import (
	"log"
	"os"
	"strconv"

	"github.com/gofiber/fiber/v3"
)

type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

func main() {
	port := "3001"
	if len(os.Args) > 1 {
		port = os.Args[1]
	}

	app := fiber.New()

	// Simple hello world
	app.Get("/", func(c fiber.Ctx) error {
		return c.SendString("Hello, World!")
	})

	// JSON response
	app.Get("/json", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"message": "Hello, World!",
			"status":  "success",
		})
	})

	// URL params
	app.Get("/user/:id", func(c fiber.Ctx) error {
		id, err := strconv.Atoi(c.Params("id"))
		if err != nil {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid ID"})
		}

		user := User{
			ID:    id,
			Name:  "John Doe",
			Email: "john@example.com",
		}
		return c.JSON(user)
	})

	// Query parameters
	app.Get("/search", func(c fiber.Ctx) error {
		query := c.Query("q", "default")
		limit := c.Query("limit", "10")

		return c.JSON(fiber.Map{
			"query":   query,
			"limit":   limit,
			"results": []string{"result1", "result2", "result3"},
		})
	})

	// POST with JSON body
	app.Post("/user", func(c fiber.Ctx) error {
		var user User
		if err := c.Bind().Body(&user); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		}

		user.ID = 123
		return c.Status(201).JSON(user)
	})

	// Form data
	app.Post("/form", func(c fiber.Ctx) error {
		name := c.FormValue("name")
		email := c.FormValue("email")

		return c.JSON(fiber.Map{
			"name":    name,
			"email":   email,
			"message": "Form received",
		})
	})

	log.Printf("Fiber v3 server starting on port %s", port)
	log.Fatal(app.Listen(":"+port, fiber.ListenConfig{DisableStartupMessage: true}))
}
