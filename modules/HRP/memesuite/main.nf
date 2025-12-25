process MEME {
  tag "$meta"
  label 'process_medium'
  container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
    ? 'docker://memesuite/memesuite:5.5.5'
    : 'memesuite/memesuite:5.5.5'}"
  publishDir(
    path: { "${params.out}/${task.process}".replace(':','/').toLowerCase() }, 
    mode: 'copy',
    overwrite: true,
    saveAs: { fn -> fn.substring(fn.lastIndexOf('/')+1) }
  ) 
  input:
      tuple val(meta), path(protein_fasta)
  
  output:
      tuple val(meta), path("*.txt"), emit: meme_out
  
  script:
      def prefix = task.ext.prefix ?: "${meta}"
  """
  meme ${protein_fasta}  \\
     -protein  \\
     -o ${prefix} \\
     -mod zoops \\
     -nmotifs 19 \\
     -minw 4 \\
     -maxw 7 \\
     -objfun classic \\
     -markov_order 0 \\
     -p $task.cpus
  
  cp ${prefix}/meme.txt ${prefix}_meme_out.txt 
  """
}

process MAST {
  tag "$meta"
  label 'process_medium'
  container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
    ? 'docker://memesuite/memesuite:5.5.5'
    : 'memesuite/memesuite:5.5.5'}"
  publishDir(
    path: { "${params.out}/${task.process}".replace(':','/').toLowerCase() }, 
    mode: 'copy',
    overwrite: true,
    saveAs: { fn -> fn.substring(fn.lastIndexOf('/')+1) }
  ) 
  input:
      tuple val(meta), path(protein_fasta), path(meme_out)
      val(pattern)
  
  output:
      tuple val(meta), path("*mast_out.txt"), emit: mast_out
      tuple val(meta), path("*mast_geneIDs.txt"), emit: mast_geneids
  
  script:
      def prefix = task.ext.prefix ?: "${meta}"
  """
  mast -o ${meta}_mast ${meme_out} ${protein_fasta}
  cp ${meta}_mast/mast.txt ${meta}_mast_out.txt
  
  # Extract gene IDs - try pattern first, fall back to extracting first column from MAST output
  if grep -oE "${pattern}" ${meta}_mast_out.txt > ${meta}_mast_geneIDs.txt 2>/dev/null && [ -s ${meta}_mast_geneIDs.txt ]; then
      echo "Extracted gene IDs using pattern: ${pattern}"
  else
      # Fallback: extract sequence names from MAST output (lines with e-value scores)
      awk '/^[A-Za-z]/ && NF>=4 && \$3 ~ /[0-9]+e-[0-9]+/ {print \$1}' ${meta}_mast_out.txt > ${meta}_mast_geneIDs.txt || true
      echo "Extracted gene IDs using fallback method"
  fi
  
  # Ensure file exists even if empty
  touch ${meta}_mast_geneIDs.txt
  """
}
