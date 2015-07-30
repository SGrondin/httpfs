using System;

namespace Httpfsc.Business.Http
{
    /// <summary>
    /// Interface pour la configuration du HttpFileSystemProxy
    /// </summary>
    public interface IHttpFileSystemProxyConfig
    {
        #region Properties

        /// <summary>
        /// The server's root URL.
        /// </summary>
        Url ServerRootPath { get; }

        #endregion
    }
}