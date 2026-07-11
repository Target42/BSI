package bootstrap

import (
	"context"
	"log/slog"
	"os"
	"path/filepath"

	"github.com/Target42/BSI/isms-server/internal/catalog"
	"github.com/Target42/BSI/isms-server/internal/config"
	"github.com/Target42/BSI/isms-server/internal/repository"
)

func EnsureGrundschutzCatalog(ctx context.Context, store *repository.Store, cfg config.Config) error {
	hasCatalog, err := store.HasCatalog(ctx, cfg.CatalogVersion)
	if err != nil {
		return err
	}
	if hasCatalog {
		return nil
	}

	xmlPath := ResolveCatalogXMLPath(cfg.CatalogXMLPath)
	if xmlPath == "" {
		slog.Warn("no IT-Grundschutz catalog in database and no XML file found",
			"hint", "set CATALOG_XML_PATH or place XML_Kompendium_2023.xml in Documents or isms-server/catalog/")
		return nil
	}

	slog.Info("importing IT-Grundschutz catalog", "file", xmlPath, "version", cfg.CatalogVersion)
	result := catalog.ImportFromFile(xmlPath)
	if !result.Success {
		slog.Warn("catalog import failed", "error", result.ErrorMessage)
		return nil
	}

	if err := store.ReplaceGrundschutzCatalog(ctx, result); err != nil {
		slog.Warn("catalog database import failed", "error", err)
		return nil
	}

	slog.Info("catalog imported",
		"bausteine", len(result.Bausteine),
		"requirements", len(result.Requirements),
		"version", result.CatalogVersion)
	return nil
}

func ResolveCatalogXMLPath(configuredPath string) string {
	const fileName = "XML_Kompendium_2023.xml"

	if configuredPath != "" {
		if info, err := os.Stat(configuredPath); err == nil && !info.IsDir() {
			return configuredPath
		}
		return ""
	}

	candidates := []string{}
	if home, err := os.UserHomeDir(); err == nil {
		candidates = append(candidates,
			filepath.Join(home, "Documents", fileName),
			filepath.Join(home, "Dokumente", fileName),
		)
	}

	candidates = append(candidates,
		filepath.Join("catalog", fileName),
		filepath.Join("isms-server", "catalog", fileName),
		filepath.Join("..", "xml", fileName),
	)

	for _, candidate := range candidates {
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return candidate
		}
	}
	return ""
}
