# Load the necessary libraries
library(ggtree)
library(tidyverse)
library(RColorBrewer)
library(ape)

# Get command-line arguments
args <- commandArgs(trailingOnly = TRUE)
lineage_csv_path <- args[1]
tree_path <- args[2]
output_path <- args[3]
fasta_path <- args[4]

# Read the tree data
tree <- read.tree(tree_path)

# Read the lineage data
lineage <- read.table(lineage_csv_path, sep=",", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)

# Convert leaf_name to rownames
rownames(lineage) <- lineage$Leaf
lineage$Leaf <- NULL

# Read the FASTA file
fasta_lines <- readLines(fasta_path)
fasta_header <- fasta_lines[1]  # Get the first line (header)

# Extract protein name and accession number from the header
# Header format: >sp_uniprotID_proteinName_speciesName_speciesID
header_parts <- strsplit(sub("^>", "", fasta_header), "_")[[1]]
accession_number <- header_parts[2]  # Extract uniprotID
protein_name <- header_parts[3]      # Extract proteinName

# Define a dictionary for color-rank matches
color_dict <- c(
  "Metazoa" = "#8C6B6B",  # Muted coral
  "Vertebrata" = "#A8A8A8",  # Light gray
  "Mammalia" = "#B86B6B",  # Soft brown with a hint of red
  "Sauria" = "#D4B9A8",  # Warm beige
  "Actinopterygii" = "#6A8EAE",  # Soft, muted blue
  "Arthropoda" = "#a7917b",  # Earthy taupe
  "Viridiplantae" = "#496e4c",  # Deep green
  "Chlorophyta" = "#9CBA9E",  # Soft green
  "Embryophyta" = "#588157",  # Darker green
  "Fungi" = "#F2E3B3",  # Light pastel yellow
  "Others" = "#9AB8C8"   # Soft light blue
)

# Filter out columns with all NA values
lineage <- lineage[, colSums(is.na(lineage)) < nrow(lineage)]

# Define the taxonomic rank groups
taxonomic_groups <- list(
  "Group1" = c("Metazoa", "Viridiplantae", "Fungi", "Others"),
  "Group2" = c("Vertebrata", "Arthropoda", "Chlorophyta", "Embryophyta"),
  "Group3" = c("Mammalia", "Sauria", "Actinopterygii")
)

# Update the taxonomic groups list to remove ranks not present in the CSV file
for (group in names(taxonomic_groups)) {
  taxonomic_groups[[group]] <- taxonomic_groups[[group]][taxonomic_groups[[group]] %in% colnames(lineage)]
}

# Create a new dataframe to store the combined lineage information
combined_lineage <- data.frame(matrix(ncol = length(taxonomic_groups), nrow = nrow(lineage)))
colnames(combined_lineage) <- names(taxonomic_groups)
rownames(combined_lineage) <- rownames(lineage)

# Fill the combined lineage dataframe
for (group in names(taxonomic_groups)) {
  for (rank in taxonomic_groups[[group]]) {
    combined_lineage[group] <- ifelse(lineage[[rank]] != "", rank, combined_lineage[[group]])
  }
}

# Create the color mapping list using the dictionary and present ranks
present_ranks <- unique(unlist(combined_lineage))
present_ranks <- present_ranks[!is.na(present_ranks)]
color_mapping <- color_dict[present_ranks]

# Rotate the tree
rotate_all <- function(tree) {
  for (idx in seq(tree$Nnode + 2, nrow(tree$edge) + 1)) {
    tree <- ape::rotate(tree, idx)
  } 
  tree
}
rotated_tree <- rotate_all(tree)

# Create the tree plot
p <- ggtree(rotated_tree, ladderize = FALSE, layout = "rectangular")

# Create the heatmap
heatmap <- gheatmap(p, combined_lineage, width = 0.2,
                    offset = 0.01, color = NULL, 
                    colnames_angle = 90, colnames = FALSE, 
                    colnames_offset_y = 0.25, hjust = 0, font.size = 2) +
  scale_fill_manual(values = color_mapping, limits = present_ranks, na.value = "white",
                    breaks = c("Metazoa", "Vertebrata", "Mammalia", "Sauria", "Actinopterygii", 
                               "Arthropoda", "Viridiplantae", "Embryophyta","Chlorophyta", "Fungi", "Others")) +
  theme(legend.position = "right", legend.title = element_text(size = 20), 
        legend.text = element_text(size = 14), legend.key.size = unit(16, 'mm'),
        plot.title = element_text(hjust = 0.5, size = 24, face = "bold")) +
  labs(fill = "Taxonomic Ranks") +
  ggtitle(paste("Lineage Tree of ", protein_name, "_", accession_number, sep = "")) 

# Save the plot
ggsave(output_path, plot = heatmap, width = 20, height = 30, dpi = 600)