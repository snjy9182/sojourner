## readDiatrack-methods
##
##
###############################################################################
##' @name readDiatrack
##' @aliases readDiatrack
##' @title readDiatrack
##' @rdname readDiatrack-methods
##' @docType methods
##'
##' @description read output file (tracks/trajecotries) from Diatrack.
##' @usage
##' readDiatrack(folder, ab.track = F, cores = 1, frameRecord = T)
##'
##' .readDiatrack(file, interact = F, ab.track = F, frameRecord = F)
##'
##'
## @method # this roxygen directive does not working
##' @param folder Full path to Diatrack .txt session files output folder.
##' @param ab.track Use absolute coordinates for tracks.
##' @param cores Number of cores used for parallel computation. This can be the cores on a workstation, or on a cluster. Tip: each core will be assigned to read in a file when paralleled.
##' @param frameRecord Add a fourth column to the track list after the xyz-coordinates for the frame that coordinate point was found (especially helpful when linking frames).
##' @param file Full path to Diatrack .mat session file.
##' @param interact Open menu to interactively choose file.

##' @examples
##' folder=system.file("extdata","SWR1",package="sojourner")
##' trackll=readDiatrack(folder)
##' str(trackll,max.level=2)



##' @details
##'
##' Note: the folder name should not contain ".", as it is a key charactero for subsequent indexing of file names.
##'
##' the absolute coordinates trajectory has moved
##'
##' trackID=fileID.frameID.duration.indexPerFile.indexPerTrackll
##'
##' This "indexPerFile" is the index within a diatrackFile, which translate to "index per movie".
##'
##' This "indexPerTrackll" is a unique index within a trackll, which can be translated to "index per folder".
##'

##' @export readDiatrack
##' @export .readDiatrack

###############################################################################

##------------------------------------------------------------------------------
## .readDiatrack
## a function to read one diatrack txt file and returns a list of tracks

.readDiatrack=function(file, interact=F,ab.track=F, frameRecord = F){

    # interactively open window
    if (interact == T) {
        file=file.choose()
    }

    file.name=basename(file)
    cat("\nReading Diatrack file: ",file.name,"...\n")

    ## skip the first 'comment line'
    data=read.table(file=file, header=F, skip=1)

    ## read in frame number line (for future use)
    frame.num=data[1,]

    ## remove frame number line for computation
    data=data[-1,]


    # frame.id
    frame.num.mx=matrix(frame.num,ncol=3,nrow=length(frame.num)/3,byrow=T)
    frame.id=unlist(frame.num.mx[,1])

    ## process the data
    # store coordinates of track in track.list
    track.list=list()
    # store absolute coordinates of track for comparison plots
    ab.track.list=list()
    # store num.tracks.per.file
    num.tracks.per.file=c()

    # select 3 column at a time
    # can use frame number to do this, but this way makes the program more
    # robust with little to non decrease in efficiency

    for (i in 1:(dim(data)[2]/3)) {

        #i=2

        triple=i*3
        track=dplyr::select(data,(triple-3+1):triple)
        colnames(track)=c("x","y","z")
        track=dplyr::filter(track,track$x!=0,track$y!=0)

        if (frameRecord){
            track <- cbind(track, "Frame" = c(frame.id[[i]]:(frame.id[[i]]+nrow(track)-1)))
        }

        # the [[]] is important, otherwise only x is included
        track.list[[i]]=track

        # store num.tracks.per.file
        num.tracks.per.file[i]=dim(track)[1]


        ## preprocess to fix coordinates from 0 to max
        ## absolute value of trajectory movement

        abTrack=data.frame(x=track$x-min(track$x),
                            y=track$y-min(track$y))
        ab.track.list[[i]]=abTrack

    }

    ## name the tracks


    # frame.id
    frame.num.mx=matrix(frame.num,ncol=3,nrow=length(frame.num)/3,byrow=T)
    frame.id=unlist(frame.num.mx[,1])

    # duration


    # duration=table(frame.id)
    duration=num.tracks.per.file

    # file.id
    file.subname=substr(file.name,
           start=nchar(file.name)-8,
           stop=nchar(file.name)-4)

    file.id=rep(file.subname,length(duration))

    # indexPerFile
    indexPerFile=seq(from=1,to=length(duration))

    ## trackID=fileID.frameID.duration.indexPerFile
    track.name=paste(file.id,frame.id,duration,indexPerFile,sep=".")

    # name the track
    names(track.list)=track.name
    names(ab.track.list)=track.name


    cat("\n", file.subname, "read and processed.\n")

    if (ab.track == T) return(ab.track.list) else return(track.list)

}

##------------------------------------------------------------------------------
## Note:the list can be named, this wil change the read.distrack.folder 's
## naming no need for naming it

# the mask file has to be named corresponding to its txt file name to work
# correspondingly. as it is read into two list, file.list, and mask.list. there
# is not direct comparison of file name function add in yet in v0.3.4

readDiatrack=function(folder,ab.track=F,cores=1, frameRecord = T){


    trackll=list()
    track.holder=c()######MERGING

    # getting a file list of Diatrack files in a directory
    file.list=list.files(path=folder,pattern=".txt",full.names=T)
    file.name=list.files(path=folder,pattern=".txt",full.names=F)
    folder.name=basename(folder)


    # read in tracks
    # list of list of data.frames,
    # first level list of file names and
    # second level list of data.frames

    max.cores=parallel::detectCores(logical=T)

    if (cores == 1){

        for (i in 1:length(file.list)){


            track=.readDiatrack(file=file.list[i],ab.track=ab.track, frameRecord = frameRecord)


            # add indexPerTrackll to track name
            indexPerTrackll=1:length(track)
            names(track)=mapply(paste,names(track),indexPerTrackll,sep=".")

            trackll[[i]]=track
            names(trackll)[i]=file.name[i]
        }

    }else{

        # parallel this block of code
        # assign reading in using .readDiatrack to each CPUs

        # detect number of cores
        # FUTURE: if more than one, automatic using multicore

        if (cores>max.cores)
            stop("Number of cores specified is greater than recomended maxium: ",max.cores)

        cat("Initiated parallel execution on", cores, "cores\n")
        # use outfile="" to display result on screen
        cl <- parallel::makeCluster(spec=cores,type="PSOCK",outfile="")
        # register cluster
        parallel::setDefaultCluster(cl)

        # pass environment variables to workers

        parallel::clusterExport(cl,varlist=c(".readDiatrack","ab.track", "frameRecord"),envir=environment())

        # trackll=parallel::parLapply(cl,file.list,function(fname){
        trackll=parallel::parLapply(cl,file.list,function(fname){
            track=.readDiatrack(file=fname,ab.track=ab.track, frameRecord = frameRecord)

            # add indexPerTrackll to track name
            indexPerTrackll=1:length(track)
            names(track)=mapply(paste,names(track),indexPerTrackll,sep=".")
            return(track)
        })

        # stop cluster
        cat("\nStopping clusters...\n")
        parallel::stopCluster(cl)

        names(trackll)=file.name
        # names(track)=file.name

    }

    # cleaning tracks by image mask
    #if (mask == T){
    #    trackll=maskTracks(folder = folder, trackll=trackll)
    #}

    # merge masked tracks
    # merge has to be done after mask

    #Merge start##########################################################################################
    # if (merge == T){
    #     for (i in 1:length(file.list)){
    #         trackll[[i]]=track[[i]]
    #         names(trackll)[i]=file.name[i]
    #     }
    # }
    #Merge end##########################################################################################

    # trackll naming scheme
    # if merge == F, list takes the name of individual file name within folder
    # file.name > data.frame.name
    # if merge == T, list takes the folder name
    # folder.name > data.frame.name
    
    # merge masked tracks
    # merge has to be done after mask
    #Mask start##########################################################################################
    #if (merge == T){

        # trackll naming scheme
        # if merge == F, list takes the name of individual file name within folder
        # file.name > data.frame.name
        # if merge == T, list takes the folder name
        # folder.name > data.frame.name

        # concatenate track list into one list of data.frames
        #for (i in 1:length(file.list)){
        #    track.holder=c(track.holder,trackll[[i]])
        #}

        # rename indexPerTrackll of index
        # extrac index
        #Index=strsplit(names(track.holder),split="[.]")  # split="\\."

        # remove the last old indexPerTrackll
        #Index=lapply(Index,function(x){
            #x=x[1:(length(x)-1)]
            #x=paste(x,collapse=".")})

        # add indexPerTrackll to track name
        #indexPerTrackll=1:length(track.holder)
        #names(track.holder)=mapply(paste,Index,
                                   #indexPerTrackll,sep=".")

        # make the result a list of list with length 1
        #trackll=list()
        #trackll[[1]]=track.holder
        #names(trackll)[[1]]=folder.name
    #}
      #Mask end ##########################################################################################
        # trackll=track.holder

    #     }else{
    #
    #         # list of list of data.frames,
    #         # first level list of folder names and
    #         # second level list of data.frames
    #
    #         for (i in 1:length(file.list)){
    #
    #             track=.readDiatrack(file=file.list[i],ab.track=ab.track)
    #             # concatenate tracks into one list of data.frames
    #             track.holder=c(track.holder,track)
    #
    #         }
    #
    #         # add indexPerTrackll to track name
    #         indexPerTrackll=1:length(track.holder)
    #
    #         names(track.holder)=mapply(paste,names(track.holder),
    #                                    indexPerTrackll,sep=".")
    #
    #         # make the result a list of list with length 1
    #         trackll[[1]]=track.holder
    #         names(trackll)[[1]]=folder.name
    #

    #
    #
    #         if (mask == T){
    #             trackll=maskTracks(trackll,mask.list)
    #         }
    #
    #     }

    cat("\nProcess complete.\n")
    
    return(trackll)
}

##-----------------------------------------------------------------------------
## Note:

## if want to keep the names of each data frame come from, use
## if (merge) do.call(c,trackll)




