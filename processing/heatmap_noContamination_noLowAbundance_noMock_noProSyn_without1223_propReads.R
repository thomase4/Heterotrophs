library(tidyverse)
library(readr)
library(readxl)
library(picante)
library(phyloseq)


setwd("~/Dropbox (MIT)/Sean16SSep2019/")

#loads corrected counts of each taxa in each sample 
#this excludes sequences that were determined to be contamination from nearby wells
seq <- read.table("seqtab_corrected.txt")

numCols <- ncol(seq)

cols <- str_c("col", 1:numCols)

#gives a number to each sequence (column)
colnames(seq) <- cols

nrow(seq)

#gets list of samples
samples <- rownames(seq)

#makes a variable for the sample in seq instead of the samples just being
#the rownames
seq <- seq %>% mutate(sample = samples)

#there are 3170 sequences without excluding any samples
numCols

nrow(seq)

#this excludes the unrelated samples 
#seq <- seq %>% filter(!str_detect(sample, "Con|Epi|Pcn|Lin"))

#gathers seq into long form
seqG <- seq %>% gather(1:3170, key = "sequence", value = "abundance")



#gets the total number of sequences in each sample
summ <- seqG %>% group_by(sample) %>% summarize(totalSeqs = sum(abundance))

nrow(seqG)

#adds number of sequences in sample to each sequence
seqG <- seqG %>% left_join(summ, by = c("sample"))

nrow(seqG)

seqG %>% filter(is.na(totalSeqs))

#gets rid of the rows for the samples that are unrelated (Sean told me which ones to exclude)
seqG <- seqG %>% filter(!str_detect(sample, "Con|Epi|Pcn|Lin"))

seqG %>% filter(str_detect(sample, "Mock")) %>% distinct(sample)

seqG <- seqG %>% filter(!str_detect(sample, "Mock"))

#gets rid of the rows for which a sequence is not present in a sample
#this excludes the sequences that are just present in the unrelated samples (Con|Epi|Pcn|Lin)
seqG <- seqG %>% filter(abundance > 0)

seqG %>% distinct(sequence) %>% nrow()

#gets the proportion that each sequence is in each sample
seqG <- seqG %>% mutate(propSample = abundance/totalSeqs)



seqG %>% distinct(sequence) %>% nrow() 

#excludes the sequences in samples that have a low relative abundances in the sample
seqG <- seqG %>% filter(propSample >= 0.002)

seqG %>% distinct(sequence) %>% nrow()

#gets rid of unnecessary variables
seqG <- seqG %>% select(-c(propSample, totalSeqs))


#makes sequence names in seqG match sequence names in repSeqs
seqG$sequence <- str_replace(seqG$sequence, "col", "contig_")

seqG %>% distinct(sequence) %>% nrow()

write_csv(seqG, "forSeanComparisonToBiogeotraces.csv")


#loads the representative sequences fasta file so that I can get the 
#contig ID assigned to each feature ID
repSeqs <- read.table("representative_sameLengthSeqs_noContamination_noMock_noProSyn_withoutSample1223.fasta", fill = TRUE)

#gets just the rows in repSeqs that correspond to IDs
repSeqs <- repSeqs %>% filter(str_detect(V1, ">"))


#doesn't include the Pro and Synechocchae features which means it doesn't include JW3
#it also doesn't include 1223 because I excluded it
repSeqs %>% distinct(V2) %>% nrow()

#does include the Pro and Synechocchae features so it does include JW3 
#and seqG includes 1223 because I haven't excluded it yet
seqG %>% distinct(sequence) %>% nrow()

nrow(repSeqs)

nrow(seqG)

#adds contig IDs to feature IDs in seqG
seqG <- seqG %>% left_join(repSeqs, by = c("sequence" = "V2"))

nrow(seqG)

#these are the sequences I don't want to include in the tree
seqG %>% filter(is.na(V1)) %>% distinct(sequence)

#these are the ones I want to include
seqG %>% filter(!is.na(V1)) %>% distinct(sequence)

#excludes Pro and Synechocchae features, and features that are just in JW3 and 1223
seqG <- seqG %>% filter(!is.na(V1))

#correct number of features
seqG %>% distinct(sequence) %>% nrow()

#gets rid of ">" in feature IDs
seqG <- seqG %>% mutate(V1 = str_replace(V1, ">", ""))


#makes feature ID, contig ID combined variable that matches 
#the IDs used in the tree file
seqG <- seqG %>% mutate(featureContig = str_c(V1, sequence, sep = ""))

#gets rid of unnecessary variables in seqG
seqG <- seqG %>% select(-c(sequence, V1))

seqG %>% distinct(featureContig) %>% nrow()
seqG %>% distinct(sample) %>% nrow()

#JW3 is already excluded because it just had one feature which was Pro.
seqG %>% filter(sample == "JW3")

#there are still features for 1223 because I haven't excluded the features that
#are in 1223 as well as other samples
seqG %>% filter(sample == "1223")

#excludes 1223
seqG <- seqG %>% filter(sample != "1223")

#correct number of features and samples
seqG %>% distinct(sample) %>% nrow()
seqG %>% distinct(featureContig) %>% nrow()

#spreads seqG so that the sequences (not including the ones only in the unrelated samples)
#that are not in a sample will have 0 abundance for that sample
seqSpread <- seqG %>% spread(key = featureContig, value = abundance, fill = 0)


dim(seqSpread)

str(seqSpread)

#makes rownames the sample
rownames(seqSpread) <- seqSpread$sample
seqSpread <- seqSpread %>% select(-sample)

#correct number of dimensions
dim(seqSpread)


library(metagenomeSeq)

#from https://rdrr.io/bioc/metagenomeSeq/man/newMRexperiment.html:
#count data is representative of the number of reads annotated for a feature
#rows should correspond to features and columns to samples

seqSpread[1:5, 1:4]

#makes dataframe for which rows are features and columns are samples
counts <- t(seqSpread)

counts[1:5, 1:4]

dim(counts)

obj <- newMRexperiment(counts)

#from https://rdrr.io/bioc/metagenomeSeq/man/cumNorm.html and 
#https://support.bioconductor.org/p/64061/
#res <- cumNorm(obj, p = cumNormStat(obj))

#these are the results from cumNorm
#the number for each sample tells me what to normalize the count data by 
#for that sample
#head(normFactors(res))

#normFactors(res) %>% str()
#normFactors(res) %>% length()

#normalizes the number of sequences in each sample by the normalization
#factor outputted by cumNorm
#2 indicates to apply over columns
#from https://www.r-bloggers.com/using-apply-sapply-lapply-in-r/
#norm <- apply(seqSpread, 2, function(x) x/normFactors(res))

#same number of dimensions which is good
#dim(norm)
#dim(seqSpread)

#seqSpread[,1]
#norm[,1]
#seqSpread[,1]/norm[,1]
#normFactors(res)

#seqSpread[,2]
#norm[,2]
#seqSpread[,2]/norm[,2]
#normFactors(res)

#seqSpread[3,]
#norm[3,]
#seqSpread[3,]/norm[3,]
#normFactors(res)

#from https://www.rdocumentation.org/packages/metagenomeSeq/versions/1.14.0/topics/cumNormMat
#this is the same as how I previously normalized by dividing the number of sequences by the 
#normalization factors, except this then multiplies by 1000
norm <- cumNormMat(obj, p = cumNormStat(obj), sl = 1000)

#none of the resulting values are more than 0 but less than 1
norm[norm < 1 & norm > 0]

str(seqSpread)
str(norm)

#makes normalized counts into a dataframe
norm <- norm %>% as.data.frame()

dim(seqSpread)
dim(norm)

#gets the transpose of norm
norm <- t(norm)

str(norm)

#makes norm a dataframe
norm <- norm %>% as.data.frame()

dim(seqSpread)
dim(norm)


##from comparingSampleIDs.R
#1213 is 1313
#WH7803 is WH7801
#SYN1320 is SYN1220
#9201.2 is 9311

#AS9601 is correct ID rather than ASN9601
#SYN9503 is correct ID rather than S9503

rownames(norm)[10] <- "1313"
#rownames(norm)[70] <- "WH7801"
rownames(norm)[61] <- "SYN1220"
rownames(norm)[21] <- "9311"
rownames(norm)[20] <- "9201"

rownames(norm)[35] <- "AS9601"
rownames(norm)[54] <- "SYN9503"

#seqG$sample <- ifelse(seqG$sample == "8102", "SYNCLADEXVI", seqG$sample)
rownames(norm)[17] <- "SYNCLADEXVI"


#makes gathered form of normalized count dataframe
normG <- norm %>% mutate(sample = row.names(norm))
normG <- normG %>% gather(1:235, key = "feature", value = "normCount")

normG %>% distinct(sample) %>% nrow()
normG %>% distinct(feature) %>% nrow()


#https://joey711.github.io/phyloseq/import-data.html#phyloseq-ize_data_already_in_r

#phyloseq - Takes as argument an otu_table and any unordered list of valid phyloseq components: 
#sample_data, tax_table, phylo, or XStringSet. The tip labels of a phylo-object (tree) must match 
#the OTU names of the otu_table, and similarly, the sequence names of an XStringSet object must match 
#the OTU names of the otu_table

#makes phyloseq object out of otu table
otu <- otu_table(norm, taxa_are_rows = FALSE)


#loads cleaned up taxonomy of the same length features, no pro, no syn, no contamination, no mock samples, no 1223 or JW3
#this is from makeTreeNodes_noContamination_noMock_noProSyn_without1223.R
tax <- read_tsv("taxonomySameLength_noContamination_noMock_noProSyn_withoutSample1223_cleanedUp.tsv")

tax %>% distinct(`Feature ID`) %>% nrow()
tax %>% nrow()

#makes just a variable with just the feature ID in seqG
normG <- normG %>% mutate(shortFeature = str_extract(feature, "[a-zA-Z0-9]*(?=contig)"))


nrow(normG)

#adds taxonomy to seqG
normG <- normG %>% left_join(tax, by = c("shortFeature" = "Feature ID"))

nrow(normG)

normG %>% filter(is.na(Taxon))

#there are no Pro or Syn features in seqG
#this makes sense because I already got rid of the sequences that had NA features
normG %>% filter(str_detect(Taxon, "Prochlorococcus")) %>% distinct(Taxon)
normG %>% filter(str_detect(Taxon, "Syn")) %>% distinct(Taxon)

colnames(normG)[2] <- "featureContig"

#makes dataframe with the taxonomy for each feature
taxPhyloseq <- normG %>% distinct(featureContig, shortTaxa)

nrow(taxPhyloseq)

#makes rownames of taxPhyloseq the feature ID
rownames(taxPhyloseq) <- taxPhyloseq$featureContig

#gets rid of feature ID variable
taxPhyloseq <- taxPhyloseq %>% select(-featureContig)

nrow(taxPhyloseq)

#makes phyloseq object out of taxPhyloseq
TAX <- tax_table(as.matrix(taxPhyloseq))

#loads rooted tree
#for this, I excluded sample 1223
tree <- read_tree("~/Dropbox (MIT)/Sean16SSep2019/exported-rooted-treeSameLength_noContamination_noMock_noProSyn_withoutSample1223/tree.nwk")



otuDF <- colnames(otu) %>% as.data.frame()

treeDF <- tree$tip.label %>% as.data.frame()

TAXDF <- TAX %>% rownames() %>% as.data.frame()


otuDF %>% nrow()

treeDF %>% nrow()

TAXDF %>% nrow()


colnames(otuDF) <- "V1"

colnames(treeDF) <- "V1"

colnames(TAXDF) <- "V1"



treeDF %>% anti_join(otuDF, by = c("V1"))
TAXDF %>% anti_join(otuDF, by = c("V1"))

otuDF %>% anti_join(treeDF, by = c("V1"))
TAXDF %>% anti_join(treeDF, by = c("V1"))

otuDF %>% anti_join(TAXDF, by = c("V1"))
treeDF %>% anti_join(TAXDF, by = c("V1"))

taxa_names(otu)
taxa_names(TAX)
taxa_names(tree)

otu
TAX
tree

#makes combined phyloseq object out of otu, TAX, tree
physeq <- phyloseq(otu, TAX, tree)

set.seed(7)

#there is a warning
unifracRes <- UniFrac(physeq, weighted = FALSE)

#makes tree
sampleTree <- unifracRes %>% hclust(method="ward.D")

#plot_heatmap(physeq, taxa.label="shortTaxa")

plot(sampleTree)

sampleTree$labels

sampleTree$order


sampleTree$labels[sampleTree$order]

#write order of clustered samples to csv file 
#so that I can load it in taxonomyStackedBarPlot_noContamination_noProSyn_withoutSample1223.R
clusterOrder <- sampleTree$labels[sampleTree$order] %>% as.data.frame()
colnames(clusterOrder)[1] <- "V1"

write_csv(clusterOrder, "orderOfClusteredSamples.csv")

#puts norm sample variable in the same order as unifrac clustering of samples
normG$sample <- factor(normG$sample, levels = sampleTree$labels[sampleTree$order])

levels(normG$sample)


#plot(tree)

#tree$node.label
#tree$tip.label

#seqG %>% distinct(V1)

#puts seqG feature ID, contig ID combined variable in the same order as the phylogenetic
#seqG$V1 <- factor(seqG$V1, levels = tree$tip.label)

#tree$tip.label
#levels(seqG$V1)



#need to reorder
#otu <- otu[sampleTree$labels,tree$tip.label]

#https://stackoverflow.com/questions/15153202/how-to-create-a-heatmap-with-a-fixed-external-hierarchical-cluster
#https://bioconductor.org/packages/devel/bioc/vignettes/phyloseq/inst/doc/phyloseq-analysis.html



normG %>% distinct(sample) %>% nrow()

normG %>% filter(normCount == 0) %>% nrow()

normG %>% filter(normCount != 0) %>% summarize(minNormCount = min(normCount))

log10(28.55414)
log10(1)

#replaces 0 normCount so I can take the log
normG$normCount <- ifelse(normG$normCount == 0, 1, normG$normCount)

#levels(seqG$V1)[1]

#tree$tip.label[1]


#seqG %>% distinct(V1) %>% write.table("featureContigs_noContamination_noPro.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)

#from treeOrderEdited_noContamination_noMock_noProSyn.txt

order <- c('92e8c83ca60e2208e0b90e4b3c8733a019e69cd0contig_413', 
           '1d264d03a24cecd55b3b95b875192abe2ca45de5contig_235', 
           '365f4031f0574305f02a3607afcf3ce2bde6a7dccontig_134', 
           '3db00bf862a8e676aac5220bf43a9f8b91995b23contig_340', 
           'e69115a49cf16059dbaefa850819633bb147d5c9contig_411', 
           '45e5cc62086882fefdea7ed6602e8e1b87298198contig_878', 
           'c81e88df700b26dc8fcfa4532b1eb579dc7277e0contig_872', 
           'e51085d87540c40210b71a02029f9d9bc8ebc1fbcontig_226', 
           '315602a67281e9a77fbd938edff362a47bc4c0f5contig_57', 
           'e9e1926ee348c07633920ba2ae8f035d30626636contig_230', 
           'e632dc48ed38320ef5d781041d137a2ed150cbabcontig_1014', 
           '1d2fb2a36375a555b2e8d24785a9888ea57b6306contig_213', 
           '82e4954b30d0dcccb49cada94cdb36a3896ca847contig_367', 
           '904053b16ba315e213073c3551328032ab81ba4ccontig_110', 
           '9fc4c5d96ab006502a2ffe4d22c7ef3833958bc7contig_46', 
           '8ef9e6e8dbc29865ab570501f29842be51c2d3f1contig_703', 
           '78641e958271c4aae9c82c731b9e8bc0ddedba6fcontig_29', 
           'e746b073ac3f81662926a1428954cbaf74945612contig_247', 
           '3557137ef142239b572056c13b52b4835df396a6contig_302', 
           '9e419cb9c1273ec8b885b4d27a279699e987e331contig_477', 
           'ce095f0f81bc5dc540b4951cbc8955bb7821e144contig_97', 
           'cf3d32288c62b3ad6b74a2170e2c27a0419b27cccontig_116', 
           'f3ac16ffa98dfa0f1c5b7c8c7a9cad25c947a21acontig_79', 
           'ec0343a9e6223070f4022bda36544a255a1e3daccontig_77', 
           'c627b2c9d00c804e43cfefc3ce4f81eb480739f4contig_80', 
           '0fa7351dc3a6ede04338c0ca882da26d297c86d2contig_566', 
           '14ae6d28205288fbc05cd0a1a270f1d642f88264contig_163', 
           '12ac5baddc804044642dfea959cb121a63d88202contig_167', 
           '5be219c9ce8dd81789fe28545f06208692a31015contig_478', 
           'b8c047138736c6f21cf0d47719a6ce7ae2efe45bcontig_234', 
           '93e5c49277ec545df03513c093c509092f98935fcontig_453', 
           '3f9119222087c3d6204079b46f0e948304295945contig_1170', 
           'c8178f5a1ae22590dd03942046b24fc1200bdd2acontig_131', 
           '25571329ccc338787c8d22b0a556d44f73831988contig_115', 
           '342238f34237e68c845eedd07a772f02d9c6914ccontig_171', 
           '5c983492e21b0c0edb30c83f379124ecdc4d3d01contig_201', 
           '8dd447bda22f13d0840f036eb88b035cc08c75afcontig_108', 
           '94350aa62b847b51474fd54d84883ac2862a7fb0contig_27', 
           '8fc1ec4edfb8995ed034bf172497fefcafc2fe15contig_138', 
           '3f23d501caba38b2143fe56f2f7ef717265696cdcontig_147', 
           '2f0e444aae462a2a420bad29cfc267394edc64e9contig_113', 
           'f50cd322335b57c083e19e996863caa538e1c227contig_175', 
           '0769100ebdd5772bc5b4d5037eb0ef8b6169ba99contig_71', 
           '3b6c4892de82569d06d0564ee594c8696ca3d42dcontig_62', 
           '07058e2dd1b3452dc7e5193af0dcdbb41e95c359contig_93', 
           '031a23c740bcf047c85fd29fb9b75822ea473a09contig_82', 
           'bb3516998d05d51d9f17dc463c8b1a8b918a506dcontig_120', 
           'ecb9cbc274716e5339d6137919aaef47ab472a21contig_185', 
           '378687c2c8cdf297104ee2d4501ab3c64c153d60contig_401', 
           'f7db3f7d40762c4ca2d1a409a4805f363821fbcecontig_378', 
           'f35190a067a596e695f0d4128939767f3dc3208bcontig_577', 
           '75791e0481c0ab1e7017ae618e99a226f2e1f8c3contig_656', 
           'd373463659e93ac4d39b36e60b73b9d56ca287cfcontig_95', 
           'b2eaef5113594bd95c8b133b612cee50c5d871d7contig_130', 
           'e2005b11bb7cfd59dfe0bb646f63d7e75f2ab6eccontig_492', 
           'e8807927ab01b054911f7d26bf2add66ced5be70contig_145',
           'ca285ab168fb08cd8f5a4a18c6b9b79cb195b2f4contig_311', 
           '93029188a1a89029fe63778f3d17b5ef002d51f0contig_74', 
           'f1e1d1742851920183773cc5710788dbe75225e8contig_7', 
           '744498c724ba4788e1f8b15c1cdac5b7781c18b3contig_3', 
           '5a29ba848d931a17cb8300cc39c6ab99a7ab42a3contig_37',
           '64310454483d7fb41d43ee44c53c74e30d884e19contig_39', 
           'aec8c2a5b36840490c780e48e88245ea9dea8416contig_449', 
           '21695678c370ccce1906b3fd15f5dec5992722b3contig_240', 
           'f75586465c014784dad0264dfee2c19f40456dfacontig_253', 
           '06c7ca2f70ccfc2f4d2f6cc8dd2ee507faa8a2d6contig_75', 
           '898183d9808ad9616e8b54419784d3dc7a5d452acontig_801', 
           '68d7a6228f2d1e562e7eb2d44694dbe928b059b3contig_140', 
           '1b2de99eaf2c31fd3b601b91805deb99adf3850bcontig_111', 
           'b1386cfc97109d19905cefb1aad7836367e7c8aecontig_177', 
           '9b5fa12fa63ec19b9bab0bcc245dfd5742f5c597contig_558', 
           'c28e62b7858197d01c334e55f5c53ec8be706667contig_616', 
           'ff5d4f76f5d2b4390102b832486c425b662b37ebcontig_808', 
           '410d213d6a92786c3713532cf7be470ede61b30dcontig_402', 
           '6cb47eba426e81df24ad4cc0029cdda0c9e9e0f4contig_383', 
           'fe2acf1eeda6c735250e530a3ddb7dfe4bdf39bdcontig_480', 
           '8e58a21646ea38203eb624af3215b070b409322ccontig_154', 
           'c0f3a49228547e48edea6d7b6ef6e683fee073dfcontig_767', 
           '243279c882c8d19e3c4c4df703881f0616839f2acontig_469',
           'b06f57c300abcf1b623d2684a1b72a05baaa8d7acontig_221', 
           '2e567db282336a5a4141fe9dcdf9845db8bbffcacontig_41', 
           '4bb50617598e3aa383f1ce05abe2f6369d3d0f23contig_25', 
           'b5c7233e14060127323d296bc031e70132bd7d50contig_334',
           '302787925193f486764894f71d3f497ddd6371fccontig_1034', 
           '44dfbfc9f8bccec9af9ed303a0c5440fb66013b2contig_252', 
           '07e1f286b121bd311e2f59c627ff7998af66c220contig_107', 
           'fbebf1dd9ce768e4fc13c8e3884dcd10f0be387econtig_300', 
           '7484f46355d3f26475b8efe206902d679e766f49contig_172', 
           '33516959b7f84954752ab39664d7343bf1f1379acontig_600', 
           '6d9b48c11696f9c3e53a17f44c763a6fdb861db8contig_98', 
           'bde61b5920df09b4308d16a5d9a4a0792209da07contig_19', 
           '90b82b140703e61137216be15b8b912bdb07c84econtig_444', 
           'a40e33545e4e4ffe4564cf1a0bc9bbe5e3faa455contig_459', 
           'd914b7b04b6f67d7e37f5360626220cbbdce2f24contig_210', 
           '54a24cf633298339898180b13a6fd2a4104acd7fcontig_63', 
           '729055e2826d6fb3d6559d80b0b094a19615caabcontig_92', 
           'fdf9f303c0029a2e2c41e5f8e8cc5cf628c77e05contig_783', 
           'c9ec5e2d6ec04c8b26948cc8b423f48fdbc49002contig_315', 
           '0ee39c2ac171d16e80450d01652e21560eea3d0econtig_989', 
           '7c287cc177e6ee7dd0fc7d6af9345616909a315bcontig_1049', 
           '5da291e6c96daea6e1b754ee70a791c566b312c7contig_555', 
           '47939504678a2896a4ccd700af2ab6e19e270e49contig_400', 
           'a7de340b756c94806ad0dc771bfc3e62c660ec8acontig_78', 
           '6d53ab3bb49cc1f31e5d01ef9cb005abb7833ca4contig_11', 
           'df1c0633211089266e862a57ec28073c80d60615contig_170', 
           'e8a9658090be4785f4af2da44d9779b347850049contig_288', 
           '300f0019e52c003e5defa26315520fd164ae5f8ccontig_17', 
           'f1467f8fed73a3cd7d867f845b307cb6c5d56a99contig_657', 
           '1b9c29f48cfea16eb23fe6c60f38f201cc021dc7contig_12', 
           '8fd8327f694ec013a1c2b0db123fbeaa19760337contig_76', 
           '15b0593c2830267b3edcdd7529b7603a80031b15contig_58', 
           'af5be717089b3227af0d2dd25dd212d1cce70818contig_30', 
           'd8b82840ca2e0c26754d7dcebbd30bfbb28ba865contig_55', 
           '720726a533e2e6e4f933f92b470ea7f64dd1727fcontig_81', 
           'd69414b25d225d5ccfa2a5b3047c84a4427535c8contig_44', 
           '72c8f652368ec988c6d3843f55de2930a870c3e1contig_73', 
           'f93cdc184e02ea5168d9d17fc9a1239fac9e895dcontig_160', 
           '51912b32392052ba67116bedaa15213a134a8631contig_199', 
           '105bd94b43e377aadd4fabaa763b8ec2e1b8088acontig_550',
           '44e6788034027462ca8044f58714fc436f2f1c5acontig_832',             
           '1d4f286582461622d8877413a23b6e09b277fd87contig_207', 
           '8f86f23937b3d279cff1d512312d9b6f260612eacontig_462', 
           'bc671cac2a5238af9f292c174dc6e41651b7467econtig_324', 
           '161618f0ca6da7ba367252d8e30641babc424fb9contig_54', 
           'c9da016c458b6e79a522112eea31744cf9579cf5contig_36', 
           '8b008cbc8b62c9ec81f91de44c8e32e29f6c03e4contig_153', 
           '7b0d85f04e0bc089926edc18fedb91d4be8bca38contig_804', 
           '6709759d656842889fd675cfee49b95927281d96contig_209', 
           '3fdf862952724c7296a2a6f30511456dc0efa760contig_191', 
           'b2b02153c02b5c8985f29998a13ab541fb59c0f4contig_831', 
           'd7742c83992de70ce648ee349b7cef4da2c23fc7contig_109', 
           'd87d88f9701b58be85d74e33de924ca6e97d80bdcontig_148', 
           '6c4b9e6fb4d82726ae66ce13bf41901bfb879feccontig_347', 
           '361c7df9120adfca9428f98b573161ed454a6295contig_776', 
           'f2c605ae6474a242a049aafefed8e81939fbb743contig_308', 
           'fb9f9c9ee5eafdc0cf1682a91f8a6aeb6b5a365fcontig_486', 
           '712a7be7b7965a7e5acd410188787bd30f7c72f4contig_407', 
           '8f827b6d59d8ab77ab6d29d4c67acc44d7098fc4contig_266',
           '867a3bbf87fa8da1e6008e1100da8476de9fd6d4contig_129', 
           '8b58745608a92e2a51a7fdbe4a8b57fe664cbb60contig_50', 
           '48683a4599adb12fc709d284b2942947d2ba63cbcontig_794', 
           '549769d99ecb65f83f9b5a0dccf8f16bc2208bc7contig_173', 
           '97095dc27e67630bfab9c956b87aa04c7ae34b9ccontig_280',  
           '7c91ab1201ba9a4e351d07595743510a95da7e47contig_119', 
           '32f53fa0d3b235ce3262c44a6312e06d1e67089dcontig_84', 
           'c114fb7025d2e3bfc4dcc79291cd7b4d0d0bd794contig_586', 
           'bd158c2e9e5a150f93eae61ff7750db168bde4f2contig_268', 
           'bcc0866fe9efadadf80bd3f5439e742497161a43contig_161', 
           '99ac23ac7de7703203dc0cf77c841e745ffe3821contig_146', 
           'd8f21b93bdb22cfda62bf78e83933a794f31c57acontig_53', 
           '832934deee3decdb151869ddbddccbd61fb994a7contig_169', 
           '434e4767e87bfb4ee526d1022adfd95302c71177contig_254', 
           '628a971b140ad4e4e7550b1fe8689312a17e78d5contig_105', 
           '9ec99d70b29a077c65227e513b9a5a0336a79a1dcontig_276', 
           '6e2877d709a8a74702e468e5f9b0be1444a53af8contig_101', 
           'ace7e51d10b54061bab4549bac8250c710ff9322contig_281', 
           '6559ac53add6fd5a10588e2aea1e56951e25d6c8contig_537', 
           '235e221a7618a2c441fd04ccffa42c545be3a230contig_637', 
           'cca3c573992dd4e34384333d29013f83b684e881contig_251', 
           '0d48ec8227a25617333999d974033f71d9c1b2a4contig_121', 
           '3b1bcd3d8c06793a64e148409bd0b025d38b6a4bcontig_59', 
           '5d207e0e61b7e0926349dd86c0c543c3494fcd39contig_569', 
           '801bab4e96f5552b83d65b2dcf07fe17dca92b32contig_203', 
           '2e1319014d3756531e387b88c187ca2247a7fa08contig_227', 
           '365a447ac6ceb2320aceba3b530db35819106ecacontig_848', 
           'cc6d79ae5407004b7150e04fff9f64be7ff8fdd3contig_15', 
           '1f1c991cc3f3a1be9b01217d37cbfa8a70ac1513contig_48', 
           '0a3c10340405666532141034d5a817e46bb8e953contig_102', 
           'd5bd361f74aa2e0cd9752f205b98b5e53e9795a2contig_8', 
           'd88a8a541f7169aeaeec9d219b6d7672b5353f72contig_916', 
           'c77fa78ab03905b11dff16797406e028f455ceeacontig_165', 
           '6d5c5e729860604ddc7323b8bf0b8db69d7e3efccontig_99', 
           '0468fcf94fc57999b4d6518905ea6408230ae54fcontig_404', 
           '93301049da2237ef43d875084e0fd5a348ae3388contig_219', 
           '9ce6b5c4e6ca101362790b1b893dabfec191e5d1contig_72', 
           '6a9056639cca586d291ea696075acb4f5b88d252contig_790', 
           '35cb1ff7219a29ae23b7326fcb82ab818451c6d9contig_174', 
           '92fc50abdbc4e1f35e3805b60c248c80ba56450acontig_267', 
           '5028b3ecacd29c1b6342960da05676f207f3440bcontig_929', 
           '1d637f5dfaa61c8580956f4f2ddb0b8a3a82c416contig_265', 
           '80d2fc8b2d1bccb842b680a6d5757dc6535733fecontig_106', 
           '585b81220bace9ed993d010355f50eabd43e85c0contig_629',
           '28c624c1b66ef167290bdc3022fdaca517ec71d1contig_112', 
           'dd27c9941deddf77756998c298517712f238d78econtig_270', 
           '5eee603d5d7a33e64c00d0562d4462708fa2d7d5contig_382', 
           '4be2356ae83c07932cf46cfcd724e009bab85d37contig_764', 
           '3e7d641184b0a37ba0a323b1b5809c58f4f0e7bacontig_128', 
           '573fed4851948b5c2a2330485ad9da27bc9034cecontig_649', 
           'cacee259decdde5e1d1d1bf671ddfb14f00c485dcontig_740', 
           'de63bc5cec27ba4fd3286a1f3bab80ed8e3c398acontig_70', 
           '95b69a76096eabc74de5c09a64b16705a47df07econtig_149', 
           '3e252083f89ea39bef3626bf6ca7f0cefc3e3fe8contig_164', 
           '10516a46d8fb91cb7ac4a675c09803be30a21b34contig_305', 
           '510c305ec7f039aa52ac6b1bb06a4d7cc5bb194fcontig_34', 
           'be1f223c05e03b81eea2c9fc5298e5784b8f4919contig_87', 
           'a3ae217bef067b40aff6d31f29fe7f25260d3278contig_104', 
           'a216f204b549d48deda3e44dfc03fd1d130b5350contig_143', 
           '7f4fe3d48a115fc375c8b2ff72c219cad97ffed2contig_1061', 
           '817dd8022f21b6cb54b5a632f2ed1136f3d06e05contig_379', 
           'b3d5ea299486af1706e18513218757ed6a69b8cecontig_261', 
           'c67976c7ea2768a559b261980cf425f3ed26c188contig_88', 
           '1acc3c0be315bdc4a546b09762acace469c154c7contig_83', 
           '6bcf5d784aa6c8985a5e64e1645d0ead693b56ffcontig_43', 
           'e6c7c0c9340d3c2eba3c8595852d76cf346985cacontig_314', 
           '64f62b9bfc43656d47b3173c7a757434c634113ccontig_370', 
           'a7bc7f8f72f6e878e120a3e9f01ed5a487cc1286contig_691', 
           'e919e4a8cecfff287a5102db357fd40c97432d51contig_316', 
           '44a4f90a158a2a50c5ea5a8d9f8f8b33baca0665contig_670', 
           '48022f01a4fde18279e3c5fea5be0a878c2f4f1acontig_187', 
           'b31ec8dbad054fcdf9a7c35b0e3037a584e70e23contig_236', 
           'bac9d4ae292130e2a43e92964015d841c259fb88contig_1012', 
           'e67f741346c09fd5f93ac6c6448402b3dc3d091dcontig_829', 
           'f6b4e3997b513457feb2f7ae38b2af1e60dbd500contig_331', 
           '3d5f05cbc2690c0ba015097a39fc9b83e0b890f7contig_501', 
           '889cd4d3aa8927e3ac7a8c3069178aeb17629be1contig_181', 
           '08ce6038c62f1e0e7b1a0244521f65814d1bb141contig_133',            
           '4ee78820e55e4d04f550e8c0bc3b83f2ee20a583contig_332', 
           '75d7a2d6072fcd5e33cb50d3721b70106aab73c8contig_263', 
           '21373a1a4220bf534bddd730e3bf8435faa1d902contig_396', 
           '6de7683f1de2158bc177ab508c1727bbd5155477contig_293', 
           '02e4bec9ed20bee6ece6416ddbbadf3c30c7cb64contig_159', 
           '4cd7d458f4452603e43e0045b5514b78554d091bcontig_395', 
           'ec081a61acd16ccdc967ba467890765717a34e95contig_144', 
           '12446cfb4d40d371e7637c0b8474d4b2640a03adcontig_176', 
           '2861c470d1b14346d0fd0d1b2f7b7075ab29fcdccontig_45', 
           '4d678c8d614b5264837f03a33221e9b20e5b0bb5contig_61', 
           '845a2064b5d70eec27773b774c65d549ad743f64contig_208', 
           'ba08b27165744c07c6208f48afbe2c02dc8c23dfcontig_539', 
           '6d50176e1582b4f52bc012f981b457bf49d57daacontig_125', 
           '4b42c786200b0f7cc0b14eb3925adc54aaa6b2aacontig_69', 
           '8a41bb772fb93bd45b480f222717a0f890823d88contig_446', 
           '4ef4dd642f60169c35209dccc683af0781cdc360contig_873', 
           'a39c8b686802fe4a25ba60a8682886fb8995bb04contig_1017', 
           '7bd1cf697292422ec98662f081c86931f9718acfcontig_132', 
           'e0fd97f2a0b99a6e627b5e8f664ea9d2029415c0contig_204')

length(order)

normG %>% distinct(featureContig) %>% nrow()

normG$featureContig <- factor(normG$featureContig, levels = rev(order))

levels(normG$featureContig)

normG %>% ggplot(aes(sample, featureContig)) + geom_tile(aes(fill = log10(normCount))) + 
  labs(x = "", fill = expression(paste("log"[10], "(Sequence relative abundance in sample)")), y = "") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 6)) + 
  scale_fill_gradient(low = "white", high = "red") + 
  theme(axis.text.y = element_blank()) + 
  theme(axis.text=element_text(size=12, color = "black"))

ggsave("heatmap_noContamination_noMock_noProSyn_withoutSample1223_propReads.png", dpi = 600, height = 6, width = 8)

png("unifracSampleTreeForHeatmap_noMock_noProSyn_withoutSample1223_propReads.png")

plot(sampleTree, labels = FALSE)

dev.off()

svg("unifracSampleTreeForHeatmap_noMock_noProSyn_withoutSample1223_propReads.svg")

plot(sampleTree, labels = FALSE)

dev.off()



plot(sampleTree)


normG %>% ggplot(aes(sample, featureContig)) + geom_tile(aes(fill = log10(normCount))) + 
  labs(x = "", fill = expression(paste("log"[10], "(Sequence relative abundance in sample)")), y = "") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 6)) + 
  scale_fill_gradient(low = "white", high = "red") + 
  theme(axis.text.y = element_blank()) + 
  theme(axis.text=element_text(size=12, color = "black")) + 
  theme(legend.position="none")

ggsave("heatmap_noContamination_noMock_noProSyn_withoutSample1223_propReads_noLegend.png", dpi = 600, height = 6, width = 8)
