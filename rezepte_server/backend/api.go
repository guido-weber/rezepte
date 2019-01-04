package backend

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// RezeptKopf represents the data sufficient for a list display
type RezeptKopf struct {
	APILink     string `JSON:"APILink"`
	UILink      string `JSON:"UILink"`
	RezeptID    int    `JSON:"RezeptID"`
	Bezeichnung string `JSON:"Bezeichnung"`
}

// RezeptDetails is the full data
type RezeptDetails struct {
	RezeptKopf
	Anleitung string `JSON:"Anleitung"`
}

// RezepteHandler serves a list of RezeptKopf as JSON
type RezepteHandler struct {
	router *mux.Router
}

// RezeptDetailsHandler serves RezeptDetails as JSON
type RezeptDetailsHandler struct {
	router *mux.Router
}

func getLink(router *mux.Router, routeName string, key int) (string, error) {
	apiRoute := router.Get(routeName)
	if apiRoute == nil {
		return "", errors.New("Route " + routeName + " nicht definiert")
	}
	url, err := apiRoute.URL("key", strconv.Itoa(key))
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

func (rk *RezeptKopf) setLinks(router *mux.Router) error {
	link, err := getLink(router, "RezeptAPI", rk.RezeptID)
	if err != nil {
		log.Fatal(err)
		return err
	}
	rk.APILink = link
	link, err = getLink(router, "RezeptUI", rk.RezeptID)
	if err != nil {
		log.Fatal(err)
		return err
	}
	rk.UILink = link
	return nil
}

func (hndlr RezepteHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	rows, err := DB.Query("SELECT rezept_id, bezeichnung FROM tbl_rezepte ORDER BY bezeichnung")
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()
	rezepte := make([]RezeptKopf, 0)
	for rows.Next() {
		var rk RezeptKopf
		if err := rows.Scan(&rk.RezeptID, &rk.Bezeichnung); err != nil {
			log.Fatal(err)
		}
		err := rk.setLinks(hndlr.router)
		if err != nil {
			log.Fatal(err)
		}
		rezepte = append(rezepte, rk)
	}
	if err := rows.Err(); err != nil {
		log.Fatal(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rezepte)
}

func (hndlr RezeptDetailsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	key := vars["key"]
	row := DB.QueryRow("SELECT rezept_id, bezeichnung, anleitung FROM tbl_rezepte where rezept_id = ?", key)
	var rd RezeptDetails
	if err := row.Scan(&rd.RezeptID, &rd.Bezeichnung, &rd.Anleitung); err != nil {
		log.Fatal(err)
	}
	err := rd.setLinks(hndlr.router)
	if err != nil {
		log.Fatal(err)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(rd)
}
