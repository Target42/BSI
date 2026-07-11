package domain

import "time"

type User struct {
	ID          int64     `json:"id"`
	Email       string    `json:"email"`
	DisplayName string    `json:"displayName"`
	IsAdmin     bool      `json:"isAdmin"`
	CreatedAt   time.Time `json:"createdAt"`
}

type Project struct {
	ID             int64     `json:"id"`
	Name           string    `json:"name"`
	Description    string    `json:"description"`
	CatalogVersion string    `json:"catalogVersion"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
	Role           string    `json:"role,omitempty"`
}

type TargetObject struct {
	ID              int64     `json:"id"`
	ProjectID       int64     `json:"projectId"`
	ParentID        int64     `json:"parentId"`
	Type            string    `json:"type"`
	ProtectionNeed  string    `json:"protectionNeed"`
	Name            string    `json:"name"`
	Description     string    `json:"description"`
	CreatedAt       time.Time `json:"createdAt"`
	UpdatedAt       time.Time `json:"updatedAt"`
}

type RequirementAssessment struct {
	ID               int64   `json:"id"`
	ProjectID        int64   `json:"projectId"`
	TargetObjectID   int64   `json:"targetObjectId"`
	RequirementID    int64   `json:"requirementId"`
	Status           string  `json:"status"`
	Note             string  `json:"note"`
	Responsible      string  `json:"responsible"`
	DueDate          *string `json:"dueDate,omitempty"`
	Version          int     `json:"version"`
	UpdatedAt        time.Time `json:"updatedAt"`
}

type BausteinApplicability struct {
	ID             int64  `json:"id"`
	ProjectID      int64  `json:"projectId"`
	TargetObjectID int64  `json:"targetObjectId"`
	BausteinID     int64  `json:"bausteinId"`
	Status         string `json:"status"`
}

type Measure struct {
	ID             int64   `json:"id"`
	ProjectID      int64   `json:"projectId"`
	TargetObjectID int64   `json:"targetObjectId"`
	RequirementID  int64   `json:"requirementId"`
	Title          string  `json:"title"`
	Description    string  `json:"description"`
	Responsible    string  `json:"responsible"`
	DueDate        *string `json:"dueDate,omitempty"`
	Status         string  `json:"status"`
	Version        int     `json:"version"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

type Baustein struct {
	ID             int64  `json:"id"`
	Standard       string `json:"standard"`
	ExternalID     string `json:"externalId"`
	Title          string `json:"title"`
	GroupName      string `json:"groupName"`
	CatalogVersion string `json:"catalogVersion"`
}

type Requirement struct {
	ID                 int64  `json:"id"`
	BausteinID         int64  `json:"bausteinId"`
	Standard           string `json:"standard"`
	ExternalID         string `json:"externalId"`
	BausteinExternalID string `json:"bausteinExternalId"`
	Title              string `json:"title"`
	Text               string `json:"text"`
	Level              string `json:"level"`
	ResponsibleRole    string `json:"responsibleRole"`
	Withdrawn          bool   `json:"withdrawn"`
}
