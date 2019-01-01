package backend

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

func spaHandler(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "../assets/index.html")
}

type Rezept struct {
	RezeptID    int32  `JSON:"RezeptID"`
	Bezeichnung string `JSON:"Bezeichnung"`
	Anleitung   string `JSON:"Anleitung"`
}

type Rezepte []Rezept

func apiHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := DB.Query("SELECT rezept_id, bezeichnung, anleitung FROM tbl_rezepte ORDER BY bezeichnung")
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()
	rezepte := make(Rezepte, 0)
	for rows.Next() {
		var rezept Rezept
		if err := rows.Scan(&rezept.RezeptID, &rezept.Bezeichnung, &rezept.Anleitung); err != nil {
			log.Fatal(err)
		}
		rezepte = append(rezepte, rezept)
	}
	if err := rows.Err(); err != nil {
		log.Fatal(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rezepte)
}

// NewRouter returns the URL router to use by the backend
func NewRouter() *mux.Router {
	router := mux.NewRouter().StrictSlash(true)
	router.PathPrefix("/assets/").Handler(http.StripPrefix("/assets/", http.FileServer(http.Dir("../assets"))))
	router.HandleFunc("/api/rezepte", apiHandler)
	router.HandleFunc("/rezepte/{key}", spaHandler)
	router.HandleFunc("/", spaHandler)
	return router
}
